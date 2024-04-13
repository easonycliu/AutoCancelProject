#!/usr/bin/python3

import os
import sys
import json
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

IGNORE_HEAD = 5
IGNORE_TAIL = 1


class RecoverTimeStabilizer:

	def __init__(self, flip_threshold):
		assert flip_threshold >= 0
		self.flip_threshold = flip_threshold
		self.buffer = []
		for _ in range(self.flip_threshold + 1):
			self.buffer.append(True)

	def get(self, recovered):
		if recovered == self.buffer[0]:
			self.buffer = [recovered for _ in range(self.flip_threshold + 1)]
		else:
			self.buffer.append(recovered)
			self.buffer.pop(0)
		return self.buffer[0]


def get_cancel_time(log_list):
	cancel_time = 0
	for x in log_list:
		if x[2] == "true":
			cancel_time += 1
	return cancel_time


def get_recover_time(log_list):
	recover_time = 0
	recover_time_stabilizer = RecoverTimeStabilizer(1)
	recover_list = [
		recover_time_stabilizer.get(x[3] == "true") for x in log_list
	]
	for recovered in recover_list:
		if not recovered:
			recover_time += 1
	return recover_time


def get_average_throughput(log_list):
	return np.mean(log_list)


def get_average_latency(log_list):
	return np.mean(log_list)


def get_p99_latency(log_list):
	if len(log_list) == 0:
		return 0
	return np.sort(log_list)[int(len(log_list) * 0.99)]


def get_log_dir_prefix(log_dir):
	prefixes = [
		"abnormal_sensitivity", "interval_sensitivity", "rally_benchmark",
		"solr_bench"
	]
	for prefix in prefixes:
		if log_dir.startswith(prefix):
			return prefix


def remove_prefix(string, prefix):
	return string[len(prefix):] if string.startswith(prefix) else string


def remove_suffix(string, suffix):
	return string[:-len(suffix)] if string.endswith(suffix) else string


def get_log_files_with_mode(log_files, mode):
	log_files_with_mode = []
	for log_file in log_files:
		if mode in log_file:
			log_files_with_mode.append(log_file)
	return log_files_with_mode


def get_exp_settings(log_files, mode):
	exp_settings = []
	for log_file in log_files:
		case = log_file.split('_')[0]
		exp_setting = remove_suffix(
			remove_suffix(
				remove_suffix(
					remove_prefix(log_file, "{}_{}_".format(case, mode)),
					"_throughput.csv"
				), "_latency.csv"
			), ".csv"
		)
		if exp_setting not in exp_settings:
			exp_settings.append(exp_setting)
	return exp_settings


def analyze_sensitivity(log_dirs):
	experiment_modes = [
		"base_w_predict", "base_wo_predict", "moo_w_predict", "moo_wo_predict",
		"normal", "wo_cancel"
	]

	avg_throughput_dict = {mode: {} for mode in experiment_modes}
	avg_latency_dict = {mode: {} for mode in experiment_modes}
	p99_latency_dict = {mode: {} for mode in experiment_modes}
	cancel_time_dict = {mode: {} for mode in experiment_modes}
	recover_time_dict = {mode: {} for mode in experiment_modes}
	for log_dir in log_dirs:
		microbenchmark = get_log_dir_prefix(log_dir)
		log_dir_wo_bench = remove_prefix(log_dir, "{}_".format(microbenchmark))
		year = log_dir_wo_bench.split('_')[0]
		month = log_dir_wo_bench.split('_')[1]
		day = log_dir_wo_bench.split('_')[2]

		log_dir_abs = os.path.join(
			os.getcwd(), "logs", "{}_{}_{}".format(year, month, day), log_dir
		)
		log_files = os.listdir(log_dir_abs)
		if len(log_files) == 0:
			exit()
		case = log_files[0].split('_')[0]

		for mode in experiment_modes:
			log_files_with_mode = get_log_files_with_mode(log_files, mode)
			lib_log_df = None
			throughput_log_df = None
			latency_log_df = None
			exp_settings = get_exp_settings(log_files_with_mode, mode)

			for exp_setting in exp_settings:
				lib_log_df = pd.read_csv(
					os.path.join(
						log_dir_abs,
						"{}_{}_{}.csv".format(case, mode, exp_setting)
					),
					dtype={
						"Cancel": str,
						"Recover": str
					}
				)
				throughput_log_df = pd.read_csv(
					os.path.join(
						log_dir_abs, "{}_{}_{}_throughput.csv".format(
							case, mode, exp_setting
						)
					)
				)
				latency_log_df = pd.read_csv(
					os.path.join(
						log_dir_abs,
						"{}_{}_{}_latency.csv".format(case, mode, exp_setting)
					)
				)

				lib_log_list = []
				for index, row in lib_log_df.iterrows():
					# if row["Times"] == 1:
					#     continue
					lib_log_list.append(row.values)

				lib_log_list = lib_log_list[IGNORE_HEAD:-IGNORE_TAIL]

				avg_throughput_dict[mode][exp_setting] = get_average_throughput(
					throughput_log_df.values.squeeze()
				)
				avg_latency_dict[mode][exp_setting] = get_average_latency(
					latency_log_df.values.squeeze()
				)
				p99_latency_dict[mode][exp_setting] = get_p99_latency(
					latency_log_df.values.squeeze()
				)
				cancel_time_dict[mode][
					exp_setting
				] = 0 if mode == "wo_cancel" else get_cancel_time(lib_log_list)
				recover_time_dict[mode][exp_setting] = get_recover_time(
					lib_log_list
				)
	return avg_throughput_dict, avg_latency_dict, p99_latency_dict, cancel_time_dict, recover_time_dict


def show_sensitivity_result(
	avg_throughput_dict, avg_latency_dict, p99_latency_dict, cancel_time_dict,
	recover_time_dict
):
	for mode in avg_throughput_dict.keys():
		exp_settings = avg_throughput_dict[mode].keys()
		for exp_setting in exp_settings:
			print(
				"Mode: {}, Settings: {}, Avg Throughput: {}, Avg Latency: {}, P99 Latency: {}, Cancel time: {}, Recover time: {}"
				.format(
					mode, exp_setting,
					np.mean(avg_throughput_dict[mode][exp_setting]),
					np.mean(avg_latency_dict[mode][exp_setting]),
					np.mean(p99_latency_dict[mode][exp_setting]),
					np.mean(cancel_time_dict[mode][exp_setting]),
					np.mean(recover_time_dict[mode][exp_setting])
				)
			)


def analyze_overhead(log_dirs):
	avg_throughput_dict = {"true": {}, "false": {}}
	p99_latency_dict = {"true": {}, "false": {}}
	for log_dir in log_dirs:
		microbenchmark = get_log_dir_prefix(log_dir)
		log_dir_wo_bench = remove_prefix(log_dir, "{}_".format(microbenchmark))
		year = log_dir_wo_bench.split('_')[0]
		month = log_dir_wo_bench.split('_')[1]
		day = log_dir_wo_bench.split('_')[2]
		log_dir_abs = os.path.join(
			os.getcwd(), "logs", "{}_{}_{}".format(year, month, day), log_dir
		)
		if microbenchmark == "rally_benchmark":
			log_files = os.listdir(log_dir_abs)
			for log_file in log_files:
				if '-' not in log_file:
					continue
				enable_autocancel = log_file.split('-')[1]
				benchmark_result_df = pd.read_csv(
					os.path.join(log_dir_abs, log_file)
				)
				benchmark_result_list = benchmark_result_df.values.tolist()
				for benchmark_result in benchmark_result_list:
					if benchmark_result[0] == "99th percentile latency":
						p99_latency_dict[enable_autocancel][
							benchmark_result[1]] = "{} {}".format(
								benchmark_result[2], benchmark_result[3]
							)
					if benchmark_result[0] == "Mean Throughput":
						avg_throughput_dict[enable_autocancel][
							benchmark_result[1]] = "{} {}".format(
								benchmark_result[2], benchmark_result[3]
							)
		elif microbenchmark == "solr_bench":
			log_files = os.listdir(log_dir_abs)
			for log_file in log_files:
				if '_' not in log_file:
					continue
				enable_autocancel = log_file.split('_')[1]
				benchmark_result_file = open(os.path.join(log_dir_abs, log_file))
				benchmark_result_dict = json.load(benchmark_result_file)
				benchmark_result_file.close()
				p99_latency_dict[enable_autocancel]["Query"] = "{} ms".format(benchmark_result_dict["task2"][0]["timings"][0]["99th"])
				total_queries = int(benchmark_result_dict["task2"][0]["timings"][0]["total-queries"])
				total_time = int(benchmark_result_dict["task2"][0]["timings"][0]["total-time"]) / 1000
				avg_throughput_dict[enable_autocancel]["Query"] = "{} qps".format(total_queries / total_time)

	return avg_throughput_dict, p99_latency_dict


def show_overhead_result(avg_throughput_dict, p99_latency_dict):
	for metrics in avg_throughput_dict["true"].keys():
		print(
			"Enable: {}, Metrics: {}, Avg Throughput: {}, P99 Latency: {}".
			format(
				"true", metrics, avg_throughput_dict["true"][metrics],
				p99_latency_dict["true"][metrics]
			)
		)
		print(
			"Enable: {}, Metrics: {}, Avg Throughput: {}, P99 Latency: {}".
			format(
				"false", metrics, avg_throughput_dict["false"][metrics],
				p99_latency_dict["false"][metrics]
			)
		)
		print("")


if __name__ == "__main__":
	if len(sys.argv) < 2:
		print("Usage: ./log_analyzer.py LOG_DIR1,LOG_DIR2,...")

	log_dirs = sys.argv[1].split(',')
	if len(log_dirs) == 0:
		exit()

	microbenchmark = get_log_dir_prefix(log_dirs[0])
	if microbenchmark == "abnormal_sensitivity" or microbenchmark == "interval_sensitivity":
		avg_throughput_dict, avg_latency_dict, p99_latency_dict, cancel_time_dict, recover_time_dict = analyze_sensitivity(
			log_dirs
		)
		show_sensitivity_result(
			avg_throughput_dict, avg_latency_dict, p99_latency_dict,
			cancel_time_dict, recover_time_dict
		)
	elif microbenchmark == "rally_benchmark" or microbenchmark == "solr_bench":
		avg_throughput_dict, p99_latency_dict = analyze_overhead(log_dirs)
		show_overhead_result(avg_throughput_dict, p99_latency_dict)
