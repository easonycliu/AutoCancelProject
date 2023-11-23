#!/usr/bin/python3

import os
import sys
import pandas as pd
import matplotlib.pyplot as plt

def get_cancel_time(log_list):
    pass

def get_recover_time(log_list):
    pass

def get_average_throughput(log_list):
    pass

def draw_throught(log_list, fig_path):
    plt.cla()
    plt.plot([x for x in range(len(log_list[7:-3]))], [x[1] for x in log_list[7:-3]])
    plt.savefig(fig_path)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ./log_analyzer.py LOG_DIR")
        
    experiment_modes = ["base_w_predict", "base_wo_predict", "moo_w_predict", "moo_wo_predict", "normal", "wo_cancel"]
    
    for mode in experiment_modes:
        log_df = pd.read_csv(os.path.join(os.getcwd(), "logs", sys.argv[1], "{}.csv".format(mode)))
        log_list = []
        for index, row in log_df.iterrows():
            if row["Times"] == 1:
                continue
            log_list.append(row.values)
            print(row.values)
        
        draw_throught(log_list, os.path.join(os.getcwd(), "logs", sys.argv[1], "{}.jpg".format(mode)))
        print(len(log_list))
    