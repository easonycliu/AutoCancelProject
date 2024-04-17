#!/usr/bin/python3

import os
import sys
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
	return np.sort(log_list)[int(len(log_list) * 0.99)]


def draw_throught(log_list, fig_path):
	plt.cla()
	plt.plot([x for x in range(len(log_list))], [x[1] for x in log_list])
	plt.savefig(fig_path)


if __name__ == "__main__":
	if len(sys.argv) < 2:
		print("Usage: ./log_analyzer.py LOG_DIR1,LOG_DIR2,...")

	experiment_modes = [
		"base_wo_predict", "base_w_predict", "moo_wo_predict", "moo_w_predict",
		"wo_cancel", "normal"
	]

	log_dirs = sys.argv[1].split(',')
	avg_throughput_dict = {mode: [] for mode in experiment_modes}
	avg_latency_dict = {mode: [] for mode in experiment_modes}
	p99_latency_dict = {mode: [] for mode in experiment_modes}
	cancel_time_dict = {mode: [] for mode in experiment_modes}
	recover_time_dict = {mode: [] for mode in experiment_modes}
	for log_dir in log_dirs:
		year = log_dir.split('_')[1]
		month = log_dir.split('_')[2]
		day = log_dir.split('_')[3]

		for mode in experiment_modes:
			lib_log_df = pd.read_csv(
				os.path.join(
					os.getcwd(), "logs", "{}_{}_{}".format(year, month, day),
					log_dir, "{}.csv".format(mode)
				),
				dtype={
					'Cancel': str,
					"Recover": str
				}
			)
			throughput_log_df = pd.read_csv(
				os.path.join(
					os.getcwd(), "logs", "{}_{}_{}".format(year, month, day),
					log_dir, "{}_throughput.csv".format(mode)
				)
			)
			latency_log_df = pd.read_csv(
				os.path.join(
					os.getcwd(), "logs", "{}_{}_{}".format(year, month, day),
					log_dir, "{}_latency.csv".format(mode)
				)
			)

			lib_log_list = []
			for index, row in lib_log_df.iterrows():
				# if row["Times"] == 1:
				#     continue
				lib_log_list.append(row.values)

			lib_log_list = lib_log_list[IGNORE_HEAD:-IGNORE_TAIL]

			avg_throughput_dict[mode].append(
				get_average_throughput(throughput_log_df.values.squeeze())
			)
			avg_latency_dict[mode].append(
				get_average_latency(latency_log_df.values.squeeze())
			)
			p99_latency_dict[mode].append(
				get_p99_latency(latency_log_df.values.squeeze())
			)
			cancel_time_dict[mode].append(
				0 if mode == "wo_cancel" else get_cancel_time(lib_log_list)
			)
			recover_time_dict[mode].append(get_recover_time(lib_log_list))
			draw_throught(
				lib_log_list,
				os.path.join(
					os.getcwd(), "logs", "{}_{}_{}".format(year, month, day),
					log_dir, "{}.jpg".format(mode)
				)
			)

	output_dict = {
		"Throughput (QPS)": [round(np.mean(avg_throughput_dict[mode]), 2) for mode in experiment_modes],
		"Mean Latency (ms)": [round(np.mean(avg_latency_dict[mode]) / 1000000, 2) for mode in experiment_modes],
		"P99 Latency (ms)": [round(np.mean(p99_latency_dict[mode]) / 1000000, 2) for mode in experiment_modes],
		"Cancel Time": [np.mean(cancel_time_dict[mode]) for mode in experiment_modes],
		"Recover Time": [np.mean(recover_time_dict[mode]) for mode in experiment_modes]
	}
	output_df = pd.DataFrame(output_dict, index=experiment_modes)
	output_df.to_markdown(buf=sys.stdout)
	print("")
