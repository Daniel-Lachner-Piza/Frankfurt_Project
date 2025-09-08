import numpy as np
import pandas as pd
import os
import neo.rawio
from neo.io import MicromedIO
from pathlib import Path
from micromed_io.trc import MicromedTRC
from shutil import copyfile


def get_valid_directories(data_path:Path, data_out_path:Path):
    """
    Get the list of valid directories containing .trc files with a sampling frequency greater than 1000 Hz.
    Args:
        data_path (Path): Path to the directory containing .trc files.
        data_out_path (Path): Path to save the output CSV file.
    Returns:
        pd.DataFrame: DataFrame containing the valid directories.
    """

    directories_ls = []
    file_out_path = data_out_path / "USB_Stick_valid_directories.csv"

    # Check if the output file already exists
    if file_out_path.is_file():
        valid_dirs_df = pd.read_csv(file_out_path)
    else:
        # Get the list of all .trc files in the directory and its subdirectories
        files_to_copy = list(data_path.glob("**/*.trc"))
        files_to_copy_sorted = np.sort(files_to_copy)

        for i, fpath in enumerate(files_to_copy_sorted):
            print(f"Processing file {i+1}/{len(files_to_copy_sorted)}: {fpath}")
            try:
                mmtrc = MicromedTRC(fpath)
                sfreq = mmtrc.get_sfreq()
                recording_date = mmtrc.get_header().recording_date
                if sfreq > 1000:
                    directories_ls.append(fpath.parent)
            except:
                print(f"Error reading file: {fpath}")
                continue
        valid_directories_ls = np.unique(directories_ls).tolist()
        print(f"Number of valid directories: {len(valid_directories_ls)}")
        # Save the list of valid directories to a CSV file
        valid_dirs_df = pd.DataFrame(valid_directories_ls, columns=['Valid_Directories'])
        valid_dirs_df.to_csv(file_out_path, index=False)
        print(f"Valid directories saved to {file_out_path}")

    return valid_dirs_df


def get_valid_files_info(data_path:Path, data_out_path:Path):

    nr_valid_files = 0

    # DIctionary to store the file information
    files_info = {
        'directory': [],
        'filepath': [],
        'filename': [],
        'recording_date': [],
        'sampling_frequency': [],
        'duration_h': [],
        'number_of_channels': [],
        'day': []
    }

    # Get the list of all .trc files in the directory and its subdirectories
    files_to_copy = list(data_path.glob("*.trc"))
    files_to_copy_sorted = np.sort(files_to_copy)

    for i, fpath in enumerate(files_to_copy_sorted):
        try:
            mmtrc = MicromedTRC(fpath)
            sfreq = mmtrc.get_sfreq()
            recording_date = mmtrc.get_header().recording_date
            if sfreq > 1000:
                ch_name = mmtrc.get_header().ch_names[0]
                test_sig = mmtrc.get_data(picks=[ch_name])
                duration_h = test_sig.shape[1] / sfreq / 3600
                n_channels = mmtrc.get_header().nb_of_channels
                print(f"Directory: {fpath.parent}")
                print(f"File {i+1}/{len(files_to_copy_sorted)}")
                print(f"Filename: {fpath}")
                print(f"Recording date: {recording_date}")
                print(f"Sampling frequency: {sfreq}")
                print(f"Duration (h): {duration_h:.2f}")
                print(f"Number of channels: {n_channels}")
                print(f"Progress: {nr_valid_files/len(files_to_copy_sorted)*100:.2f}%")
                print("\n")
                nr_valid_files += 1

                # Append the file information to the dictionary
                files_info['directory'].append(fpath.parent)
                files_info['filepath'].append(fpath)
                files_info['filename'].append(fpath.name)
                files_info['recording_date'].append(recording_date)
                files_info['sampling_frequency'].append(sfreq)
                files_info['duration_h'].append(duration_h)
                files_info['number_of_channels'].append(n_channels)
                files_info['day'].append(recording_date.day)
                pass
            else:
                print(f"File {fpath} has a sampling frequency of {sfreq} Hz, skipping...")
                continue
        except:
            print(f"Error reading file: {fpath}")
            continue

    # Create a DataFrame from the dictionary
    files_info_df = pd.DataFrame(files_info)
    files_info_df = files_info_df.sort_values('recording_date').reset_index(drop=True)
    # Convert the recording date to a datetime object
    files_info_df['recording_date'] = files_info_df['recording_date'].apply(pd.to_datetime)

    # get the day for each file with respect to the earliest date
    # Get the earliest recording date
    earliest_date = files_info_df['recording_date'].min()
    # Calculate the day for each file with respect to the earliest date
    files_info_df['day'] = [(pd.to_datetime(record_date)-earliest_date).days for record_date in files_info_df.recording_date]
        
    return files_info_df

if __name__ == "__main__":

    data_path = Path("E:/")
    data_out_path = Path(os.getcwd()) / 'Output'

    # Create the output directory if it doesn't exist
    os.makedirs(data_out_path, exist_ok=True)

    # Call the function to get valid directories
    # and save the output to a CSV file
    valid_dirs_df = get_valid_directories(data_path=data_path, data_out_path=data_out_path)
    
    files_info_df = pd.DataFrame()
    for i, row in valid_dirs_df.iterrows():
        
        data_path = Path(row['Valid_Directories'])
        print(f"Processing directory: {data_path}, {i+1}/{len(valid_dirs_df)}")

        # Call the function to get valid files information
        this_files_info_df = get_valid_files_info(data_path=data_path, data_out_path=data_out_path)
        # Append the DataFrame to the main DataFrame
        files_info_df = pd.concat([files_info_df, this_files_info_df], ignore_index=True)
        print("\n\n")

    # Save the files information DataFrame to a CSV file
    files_info_df.to_csv(data_out_path / "USB_Stick_files_info.csv", index=False)
    print(f"Files information saved to {data_out_path / 'USB_Stick_files_info.csv'}")
