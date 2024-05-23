#!/usr/bin/python3

import os
import sys
import json
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

from metrics_auxiliary import get_cancel_time, get_recover_time, get_average_throughput, get_average_latency, get_p99_latency


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
		"base_wo_predict", "base_w_predict", "moo_wo_predict", "moo_w_predict",
		"wo_cancel", "normal"
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
					throughput_log_df.values.squeeze()
				)
	return avg_throughput_dict, avg_latency_dict, p99_latency_dict, cancel_time_dict, recover_time_dict


def show_sensitivity_result(
	avg_throughput_dict, avg_latency_dict, p99_latency_dict, cancel_time_dict,
	recover_time_dict
):
	experiment_modes = list(avg_throughput_dict.keys())
	exp_settings = list(avg_throughput_dict[experiment_modes[0]].keys())
	output_dict = {
		"Settings": [exp_setting for mode in experiment_modes for exp_setting in exp_settings],
		"Throughput (QPS)": [round(np.mean(avg_throughput_dict[mode][exp_setting]), 2) for mode in experiment_modes for exp_setting in exp_settings],
		"Mean Latency (ms)": [round(np.mean(avg_latency_dict[mode][exp_setting]) / 1000000, 2) for mode in experiment_modes for exp_setting in exp_settings],
		"P99 Latency (ms)": [round(np.mean(p99_latency_dict[mode][exp_setting]) / 1000000, 2) for mode in experiment_modes for exp_setting in exp_settings],
		"Cancel Time": [np.mean(cancel_time_dict[mode][exp_setting]) for mode in experiment_modes for exp_setting in exp_settings],
		"Recover Time": [np.mean(recover_time_dict[mode][exp_setting]) for mode in experiment_modes for exp_setting in exp_settings]
	}
	output_df = pd.DataFrame(output_dict, index=[mode for mode in experiment_modes for exp_setting in exp_settings])
	output_df.to_markdown(buf=sys.stdout)
	print("")


def analyze_overhead(log_dirs):
	avg_throughput_dict = {}
	p99_latency_dict = {}
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
				client_num = remove_suffix(log_file, ".csv").split('-')[-1]
				if client_num not in avg_throughput_dict.keys():
					avg_throughput_dict[client_num] = {"true": {}, "false": {}}
				if client_num not in p99_latency_dict.keys():
					p99_latency_dict[client_num] = {"true": {}, "false": {}}
				benchmark_result_df = pd.read_csv(
					os.path.join(log_dir_abs, log_file)
				)
				benchmark_result_list = benchmark_result_df.values.tolist()
				for benchmark_result in benchmark_result_list:
					if benchmark_result[0] == "99th percentile latency":
						p99_latency_dict[client_num][enable_autocancel][
							benchmark_result[1]] = "{} {}".format(
								benchmark_result[2], benchmark_result[3]
							)
					if benchmark_result[0] == "Mean Throughput":
						avg_throughput_dict[client_num][enable_autocancel][
							benchmark_result[1]] = "{} {}".format(
								benchmark_result[2], benchmark_result[3]
							)
		elif microbenchmark == "solr_bench":
			log_files = os.listdir(log_dir_abs)
			for log_file in log_files:
				if '_' not in log_file:
					continue
				enable_autocancel = log_file.split('_')[1]
				client_num = remove_suffix(log_file, ".csv").split('-')[-2]
				if client_num not in avg_throughput_dict.keys():
					avg_throughput_dict[client_num] = {"true": {}, "false": {}}
				if client_num not in p99_latency_dict.keys():
					p99_latency_dict[client_num] = {"true": {}, "false": {}}
				benchmark_result_file = open(
					os.path.join(log_dir_abs, log_file)
				)
				benchmark_result_dict = json.load(benchmark_result_file)
				benchmark_result_file.close()
				p99_latency_dict[client_num][enable_autocancel]["Query"] = "{} ms".format(
					benchmark_result_dict["task2"][0]["timings"][0]["99th"]
				)
				total_queries = int(
					benchmark_result_dict["task2"][0]["timings"][0]
					["total-queries"]
				)
				total_time = int(
					benchmark_result_dict["task2"][0]["timings"][0]
					["total-time"]
				) / 1000
				avg_throughput_dict[client_num][enable_autocancel][
					"Query"] = "{} qps".format(total_queries / total_time)

	return avg_throughput_dict, p99_latency_dict


def show_overhead_result(avg_throughput_dict, p99_latency_dict):
	enable_list = ["true", "false"]
	client_num_list = list(avg_throughput_dict.keys())
	metrics_list = list(avg_throughput_dict[client_num_list[0]][enable_list[0]].keys())
	output_dict = {
		"Enable": [enable for metrics in metrics_list for enable in enable_list],
		"Throughput (QPS)": [avg_throughput_dict[client_num][enable][metrics] for metrics in metrics_list for enable in enable_list for client_num in client_num_list],
		"P99 Latency (ms)": [p99_latency_dict[client_num][enable][metrics] for metrics in metrics_list for enable in enable_list for client_num in client_num_list]
	}
	output_df = pd.DataFrame(output_dict, index=[metrics for metrics in metrics_list for enable in enable_list])
	output_df.to_markdown(buf=sys.stdout)
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
