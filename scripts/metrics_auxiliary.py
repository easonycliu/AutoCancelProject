import heapq
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

RECOVER_PERFORMANCE_DROP_PORTION = 0.3
RECOVER_PERFORMANCE_DROP_ABSOLUTE = 500

IGNORE_HEAD = 12
IGNORE_TAIL = 2

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


def __is_recovered(log_list, index):
	return (np.mean(heapq.nlargest(8, log_list)) * (1 - RECOVER_PERFORMANCE_DROP_PORTION)) < log_list[index] and (np.mean(heapq.nlargest(8, log_list)) - RECOVER_PERFORMANCE_DROP_ABSOLUTE) < log_list[index];

def get_cancel_time(log_list):
	log_list_stripped = log_list[IGNORE_HEAD:-IGNORE_TAIL]
	cancel_time = 0
	for x in log_list_stripped:
		if x[0] == 2 and x[2] == "true":
			cancel_time += 1
	return cancel_time - 1


def get_recover_time(log_list):
	log_list_stripped = log_list[IGNORE_HEAD:-IGNORE_TAIL]
	recover_time = 0
	recover_time_stabilizer = RecoverTimeStabilizer(1)
	recover_list = [
		recover_time_stabilizer.get(__is_recovered(log_list_stripped, index)) for index in range(len(log_list_stripped))
	]
	for recovered in recover_list:
		if not recovered:
			recover_time += 1
	return recover_time


def get_average_throughput(log_list):
	log_list_stripped = log_list[IGNORE_HEAD:-IGNORE_TAIL]
	return np.mean(log_list_stripped)


def get_average_latency(log_list):
	log_list_stripped = log_list[IGNORE_HEAD:-IGNORE_TAIL]
	return np.mean(log_list_stripped)


def get_p99_latency(log_list):
	log_list_stripped = log_list[IGNORE_HEAD:-IGNORE_TAIL]
	return np.sort(log_list_stripped)[int(len(log_list_stripped) * 0.99)]


def draw_throught(log_list, fig_path):
	log_list_stripped = log_list[IGNORE_HEAD:-IGNORE_TAIL]
	plt.cla()
	plt.plot([x for x in range(len(log_list_stripped))], [x[1] for x in log_list_stripped])
	plt.savefig(fig_path)


