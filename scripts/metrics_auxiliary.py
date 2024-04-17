import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

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


