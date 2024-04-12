#!/usr/bin/python3

import os
import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

IGNORE_HEAD = 5
IGNORE_TAIL = 1


def get_average_throughput(log_list):
	return np.mean(log_list)


def get_average_latency(log_list):
	return np.mean(log_list)


def get_p99_latency(log_list):
	return np.sort(log_list)[int(len(log_list) * 0.99)]


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

	for case in experiment_cases:
		print(
			"case: {}, Avg Throughput: {}, Avg Latency: {}, P99 Latency: {}"
			.format(
				case, 
				np.mean(avg_throughput_dict[case]),
				np.mean(avg_latency_dict[case]),
				np.mean(p99_latency_dict[case])
			)
		)
