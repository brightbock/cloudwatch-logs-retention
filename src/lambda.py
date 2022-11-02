import botocore
import boto3
import re
import os
import sys
import time
from datetime import datetime


def refresh_regions(seed_region):
    regions = [seed_region]
    try:
        client = boto3.client(
            "ec2",
            region_name=seed_region,
            config=botocore_configuration,
        )
        regions = [
            region["RegionName"]
            for region in client.describe_regions(
                AllRegions=True,
                Filters=[
                    {
                        "Name": "opt-in-status",
                        "Values": [
                            "opt-in-not-required",
                            "opted-in",
                        ],
                    },
                ],
            )["Regions"]
        ]
    except (
        botocore.exceptions.ClientError,
        botocore.exceptions.EndpointConnectionError,
    ) as e:
        print("ERROR: Refreshing region list from {} failed ({})".format(seed_region, e))
        pass
    return sorted(set(regions))


def lambda_handler(event, context):
    global last_execution_time
    global region_list_refresh_time
    global region_list

    counter_log_groups = 0
    counter_log_groups_changed = 0
    counter_log_groups_filtered = 0

    timestamp_now = int(datetime.now().timestamp())

    if (timestamp_now - last_execution_time) < 600:
        print("WARNING: Execution Throttled - Try again in 10 minutes")
        return
    last_execution_time = timestamp_now

    if DISCOVER_REGIONS and ((timestamp_now - region_list_refresh_time) > CACHE_TTL_SECONDS_REGION_LIST):
        region_list_refresh_time = timestamp_now
        region_list = refresh_regions(SEED_REGION)

    for region_index, region in enumerate(region_list):

        print("==== [{:04d}/{:04d}] REGION: {}".format(region_index + 1, len(region_list), region))

        client = boto3.client(
            "logs",
            region_name=region,
            config=botocore_configuration,
        )

        try:
            paginator = client.get_paginator("describe_log_groups")
            page_iterator = paginator.paginate(limit=10)

            for page in page_iterator:

                for log_group in page["logGroups"]:
                    counter_log_groups += 1

                    log_group_name = log_group["logGroupName"]
                    current_retention = log_group["retentionInDays"] if "retentionInDays" in log_group else None

                    if re.search(REGEX_EXCLUDE, log_group_name) or not re.search(REGEX_MATCH, log_group_name):
                        counter_log_groups_filtered += 1
                        if DRY_RUN:
                            print("== [{}] FILTER [{:04d}] {}".format(region, current_retention if current_retention else 9999, log_group_name))
                        continue

                    if current_retention and (current_retention <= RETENTION_DAYS_MAX) and (current_retention >= RETENTION_DAYS_MIN):
                        if DRY_RUN:
                            print("== [{}] ACCEPT [{:04d} <= {:04d} <= {:04d}] {}".format(region, RETENTION_DAYS_MIN, current_retention, RETENTION_DAYS_MAX, log_group_name))
                        continue

                    for attempt in range(1):
                        try:

                            if not DRY_RUN:
                                client.put_retention_policy(logGroupName=log_group_name, retentionInDays=RETENTION_DAYS_TARGET)
                                counter_log_groups_changed += 1
                            print(
                                "== [{}] CHANGE [FROM:{:04d} TO:{:04d}] {}{}".format(
                                    region,
                                    current_retention if current_retention else 9999,
                                    RETENTION_DAYS_TARGET,
                                    log_group_name,
                                    " [DRY_RUN]" if DRY_RUN else "",
                                )
                            )
                            break

                        except botocore.exceptions.ClientError as e:
                            if e.response["Error"]["Code"] == "ThrottlingException":
                                print("WARNING: ThrottlingException - Cycle:{:02d} {}".format(attempt, log_group_name))
                                time.sleep(4 + (attempt * 20))
                                continue
                            print("ERROR: {}".format(str(e)))
                            break

        except botocore.exceptions.ClientError as e:
            print("WARNING: {}".format(str(e)))
            # Next region
            continue
    print(
        "==== SUMMARY: Regions:{}, LogGroups:{}, Filtered:{}, Changed:{}{} ====".format(
            len(region_list),
            counter_log_groups,
            counter_log_groups_filtered,
            counter_log_groups_changed,
            " [DRY_RUN]" if DRY_RUN else "",
        )
    )


# Debug logging
# boto3.set_stream_logger(name='botocore')

RETENTION_ACCEPTABLE = [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653]
RETENTION_ACCEPTABLE_MAX = max(RETENTION_ACCEPTABLE)
RETENTION_DAYS_TARGET = int(os.getenv("RETENTION_DAYS_TARGET", RETENTION_ACCEPTABLE_MAX))
RETENTION_DAYS_MIN = int(os.getenv("RETENTION_DAYS_MIN", 0))
RETENTION_DAYS_MAX = int(os.getenv("RETENTION_DAYS_MAX", 99999))
CACHE_TTL_SECONDS_REGION_LIST = int(os.getenv("CACHE_TTL_SECONDS_REGION_LIST", 86400 * 7))
SEED_REGION = os.getenv("SEED_REGION", "us-east-1")
DISCOVER_REGIONS = str(os.getenv("DISCOVER_REGIONS", "true")).strip().lower() in ["yes", "true", "1"]
DRY_RUN = str(os.getenv("DRY_RUN", "true")).strip().lower() not in ["no", "false", "0"]
REGEX_MATCH = re.compile(os.getenv("REGEX_MATCH", ""), flags=re.X)
REGEX_EXCLUDE = re.compile(os.getenv("REGEX_EXCLUDE", "^$"), flags=re.X)

if (RETENTION_DAYS_TARGET > RETENTION_ACCEPTABLE_MAX) or (RETENTION_DAYS_TARGET < min(RETENTION_ACCEPTABLE)):
    RETENTION_DAYS_TARGET = RETENTION_ACCEPTABLE_MAX
if RETENTION_DAYS_TARGET not in RETENTION_ACCEPTABLE:
    for days in RETENTION_ACCEPTABLE:
        if days > RETENTION_DAYS_TARGET:
            RETENTION_DAYS_TARGET = days
            break

botocore_configuration = botocore.config.Config(retries={"mode": "standard", "max_attempts": 2})
try:
    # Considering this makes multiple sequential calls to each region's CWL endpoint
    # enabling TCP keepalive is a good idea. However the version of botocore
    # included in Lambda/python3.9 runtime is currently 1.23.32, and `tcp_keepalive` is
    # from version 1.27.84. So try it, and recover gracefully on failure:
    botocore_configuration = botocore_configuration.merge(botocore.config.Config(tcp_keepalive=True))
except TypeError:
    print("INFO: Current botocore version does not support TCP keepalive")
    pass

last_execution_time = 0
region_list_refresh_time = 0
region_list = [SEED_REGION]

if __name__ == "__main__":
    context = []
    event = {}
    lambda_handler(event, context)
