import numpy as np
import pandas as pd
import os
import mne
import neo.rawio
from neo.io import MicromedIO
from pathlib import Path
from micromed_io.trc import MicromedTRC
from shutil import copyfile


def copy_selecetd_files(data_path:str=None, data_out_path:str=None):

    nr_valid_files = 0
    files_to_copy = list(data_path.glob("**/*.trc"))
    files_to_copy_sorted = [str(fname) for fname in files_to_copy]
    files_to_copy_sorted.sort()
    for path in files_to_copy_sorted:
        try:
            mmtrc = MicromedTRC(path)
            sfreq = mmtrc.get_sfreq()
            recording_date = mmtrc.get_header().recording_date
            if sfreq > 1000:
                ch_name = mmtrc.get_header().ch_names[0]
                test_sig = mmtrc.get_data(picks=[ch_name])
                duration_h = test_sig.shape[1] / sfreq / 3600
                n_channels = mmtrc.get_header().nb_of_channels
                print(f"\nFilename: {path}")
                print(f"Recording date: {recording_date}")
                print(f"Sampling frequency: {sfreq}")
                print(f"Duration (h): {duration_h:.2f}")
                print(f"Number of channels: {n_channels}")
                nr_valid_files += 1
        except:
            print(f"Error reading file: {path}")
            continue
    
    files_to_copy = list(data_path.glob("**/*.trc"))
    files_dict = {'PatName': [], 'Filepath': []}
    processed_files_nr = 0
    files_to_copy = files_to_copy
    for path in files_to_copy:
        try:
            subj_name = path.parts[-2]
            fname = path.parts[-1]
            group = path.parts[-4]
            files_dict['PatName'].append(fname)
            files_dict['Filepath'].append(path)
            mmtrc = MicromedTRC(path)
            sfreq = mmtrc.get_sfreq()

            print(f"{subj_name} {fname} --- sfreq= {sfreq}")
            if sfreq > 1000:
                new_fn = f"{subj_name}_{fname}"

                os.makedirs(data_out_path, exist_ok=True)
                new_fpath = data_out_path / new_fn
                new_fpath = Path(str(new_fpath).replace(" ", "_"))
                if not os.path.isfile(new_fpath):
                    copyfile(path, new_fpath)
                
                processed_files_nr += 1
                print(f"Progress: {processed_files_nr/nr_valid_files*100:.2f}%")
        except:
            print(f"Error reading file: {path}")
            continue
        pass
    pass

if __name__ == "__main__":

    data_path = Path("D:/")
    data_out_path = Path(os.getcwd()) / 'Output'

    # Save the files information DataFrame to a CSV file
    files_info_fpath = data_out_path / "USB_Stick_files_info.csv"

    if files_info_fpath.is_file():
        print(f"File {files_info_fpath} already exists, loading it...")
        files_info_df = pd.read_csv(files_info_fpath)

        dir_ls = files_info_df.directory.str.replace(os.sep, '-').to_numpy()
        pats_ls = np.unique(dir_ls)

        clae_files_df = pd.DataFrame()

        # select a file from the third day of each patient, if it doesn't exist, select the last file
        for pat_dir in pats_ls:
            pat_name = Path(pat_dir.replace("-", os.sep)).name
            print(f"Processing patient: {pat_name}")

            # Select the files from the patient being processed
            pat_sel = np.array(dir_ls) == np.array([pat_dir])
            pat_files_info = files_info_df[pat_sel].reset_index(drop=True).copy()

            # Select the files from the third or last day of the patient being processed
            day_to_select = 3
            if pat_files_info['day'].max() < day_to_select:
                day_to_select = pat_files_info['day'].max()

            files_sel = np.logical_and(pat_files_info['day'] == day_to_select, pat_files_info['duration_h'] > 4)
            pat_selected_day_files_info = pat_files_info[files_sel].reset_index(drop=True).copy()

            # Select a random file from the last day of the patient being processed
            if pat_selected_day_files_info.shape[0]>0:
                if pat_selected_day_files_info.shape[0]>1:
                    random_pat_file_info = pat_selected_day_files_info.sample(n=1, random_state=42).reset_index(drop=True).copy()
                else:
                    random_pat_file_info = pat_selected_day_files_info.copy()

                clae_files_df = pd.concat([clae_files_df, random_pat_file_info], ignore_index=True)
            else:
                print(f"No files found for patient {pat_name} on day {day_to_select}")
                pass
            pass
        pass
    else:
        print(f"File {files_info_fpath} does not exist")

    random_pat_files_fpath = data_out_path / "USB_Stick_random_pat_files.csv"
    clae_files_df.to_csv(random_pat_files_fpath, index=False)
    pass
        

