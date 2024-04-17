#!/usr/bin/python3

import os
import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

from metrics_auxiliary import get_average_throughput, get_average_latency, get_p99_latency, get_recover_time

IGNORE_HEAD = 5
IGNORE_TAIL = 1


if __name__ == "__main__":
	if len(sys.argv) < 2:
		print("Usage: ./log_analyzer.py LOG_DIR1,LOG_DIR2,...")

	experiment_cases = [
		"c1", "c3", "c4", "c5", "c6", "c7"
	]

	log_dirs = sys.argv[1].split(',')
	avg_throughput_dict = {case: [] for case in experiment_cases}
	avg_latency_dict = {case: [] for case in experiment_cases}
	p99_latency_dict = {case: [] for case in experiment_cases}
	cancel_time_dict = {case: [] for case in experiment_cases}
	recover_time_dict = {case: [] for case in experiment_cases}
	for log_dir in log_dirs:
		baseline = log_dir.split('_')[0]
		year = log_dir.split('_')[1]
		month = log_dir.split('_')[2]
		day = log_dir.split('_')[3]

		for case in experiment_cases:
			throughput_log_df = pd.read_csv(
				os.path.join(
					os.getcwd(), "logs", "{}_{}_{}".format(year, month, day),
					log_dir, "{}_{}_throughput.csv".format(baseline, case)
				)
			)
			latency_log_df = pd.read_csv(
				os.path.join(
					os.getcwd(), "logs", "{}_{}_{}".format(year, month, day),
					log_dir, "{}_{}_latency.csv".format(baseline, case)
				)
			)

			avg_throughput_dict[case].append(
				get_average_throughput(throughput_log_df.values.squeeze())
			)
			avg_latency_dict[case].append(
				get_average_latency(latency_log_df.values.squeeze())
			)
			p99_latency_dict[case].append(
				get_p99_latency(latency_log_df.values.squeeze())
			)
			cancel_time_dict[case].append(
				0
			)
			recover_time_dict[case].append(
				get_recover_time(throughput_log_df.values.squeeze())
			)

	output_dict = {
		"Throughput (QPS)": [round(np.mean(avg_throughput_dict[case]), 2) for case in experiment_cases],
		"Mean Latency (ms)": [round(np.mean(avg_latency_dict[case]) / 1000000, 2) for case in experiment_cases],
		"P99 Latency (ms)": [round(np.mean(p99_latency_dict[case]) / 1000000, 2) for case in experiment_cases],
		"Cancel Time": [np.mean(cancel_time_dict[case]) for case in experiment_cases],
		"Recover Time": [np.mean(recover_time_dict[case]) for case in experiment_cases]
	}
	output_df = pd.DataFrame(output_dict, index=experiment_cases)
	output_df.to_markdown(buf=sys.stdout)
	print("")
