#!/usr/bin/python3
import sys
import os

import pandas as pd
import numpy as np

from cases_analyzer import analyze_case, show_case_result

cases_names = ["c1", "c3", "c4", "c5", "c6", "c7"]
microbenchmark_names = ["abnormal_sensitivity", "rally_benchmark", "solr_bench"]
baseline_names = ["parties", "psp", "psandbox"]

if __name__ == "__main__":
	exp_name = sys.argv[1]
	exp_type = None
	analyze_func = None
	show_result_func = None
	if exp_name in cases_names:
		exp_type = "cases"
		analyze_func = analyze_case
		show_result_func = show_case_result
	elif exp_name in microbenchmark_names:
		exp_type = "microbenchmark"
	elif exp_name in baseline_names:
		exp_type = "baseline"
	else:
		print("Error arg")
		print("\tChoices: {}".format(cases_names + microbenchmark_names + baseline_names))
		exit()

	file_names_df = pd.read_csv(os.path.join(os.getcwd(), "results", exp_type, "{}.csv".format(exp_name)), header=None)
	file_names_list = list(np.array(file_names_df.values.tolist()).squeeze())
	avg_throughput_dict, avg_latency_dict, p99_latency_dict, cancel_time_dict, recover_time_dict = analyze_func(file_names_list)

	show_result_func(avg_throughput_dict, avg_latency_dict, p99_latency_dict, cancel_time_dict, recover_time_dict)

