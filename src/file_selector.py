import numpy as np
import pandas as pd
import os
import neo.rawio
import pandas_access as mdb
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


def read_database(db_path, db_fname):
    # List tables in the MDB file
    db_fpath = db_path / db_fname
    for table_name in mdb.list_tables(str(db_fpath)):
        print(table_name)

    # Read a specific table into a pandas DataFrame
    table_name = 'your_table'
    df = mdb.read_table(db_filename, table_name)

    # Display the first few rows of the DataFrame
    print(df.head())

if __name__ == "__main__":

    data_path = Path("D:/")
    data_path = Path("D:/VEME/patients/FR07MM31")     
    data_out_path = Path("C:/Users/HFO/Documents/Postdoc_Calgary/Research/FRA_Project/EEG_Data")
    data_out_path = Path("D:/Selected_EEGs")
    
    copy_selecetd_files(data_path=data_path, data_out_path=data_out_path)

    database_pat = Path("D:/VEME/database")
    db_fname = "local archive system98.mdb"
    #read_database(db_path=database_pat, db_fname=db_fname)
