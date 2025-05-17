% This script converts EEG data from Micromed format to BrainVision format
% using FieldTrip toolbox.
% It reads .TRC files, processes the data, and saves it in BrainVision format.
% The script assumes that the FieldTrip toolbox is installed and added to the MATLAB path.
% The script also assumes that the EEG data is stored in a specific directory structure.
% The script processes multiple files in a loop, and the output files are saved in the same directory as the input files.
% The script uses the ft_read_header and ft_read_data functions from FieldTrip toolbox to read the EEG data.
clear all; close all;clc;

[path,~,~] = fileparts(mfilename('fullpath'));
cutIdx = strfind(path, '\');
workspacePath = path(1:cutIdx(end));
cd(workspacePath)


files_ls = {
    "D:\VEME\patients\FR05KO27\EEG_157.TRC";
    "D:\VEME\patients\FR06KS33\EEG_185.TRC";
    "D:\VEME\patients\FR07MM31\EEG_193.TRC";
    "D:\VEME\patients\FR08VP35\EEG_203.TRC";
    "D:\VEME2\patients\PAT_1 FR09SH68\EEG_21.TRC";
    "D:\VEME2\patients\PAT_10 FR20SB35\EEG_178.TRC";
    "D:\VEME2\patients\PAT_11 FR21RT77 1.Teil\EEG_207.TRC";
    "D:\VEME2\patients\PAT_2 FR10BC63\EEG_43.TRC";
    "D:\VEME2\patients\PAT_5 FR13AS39\EEG_96.TRC";
    "D:\VEME2\patients\PAT_6 FR14SA31\EEG_107.TRC";
    "D:\VEME2\patients\PAT_7 FR16DP69\EEG_124.TRC";
    "D:\VEME2\patients\PAT_9 FR19PS61\EEG_144.TRC";
    "D:\VEME3\patients\PAT_1 FR21RT77 2.Teil\EEG_13.TRC";
    "D:\VEME3\patients\PAT_13 FR117MW31\EEG_424.TRC";
    "D:\VEME3\patients\PAT_2 FR22ZA78\EEG_32.TRC";
    "D:\VEME3\patients\PAT_4 FR24AS38\EEG_119.TRC";
    "D:\VEME3\patients\PAT_6 FR26KP38\EEG_211.TRC";
    "D:\VEME3\patients\PAT_7 FR27WI37\EEG_223.TRC";
    "D:\VEME3\patients\PAT_8 FR28TG59\EEG_234.TRC";
    "D:\VEME3\patients\PAT_9 FR29SJ40\EEG_257.TRC";
    };

ftPath = strcat('C:\Users\HFO\Documents\Postdoc_Calgary\Research\fieldtrip-20221121');
addpath(ftPath);
ft_defaults;

for fi = 1:length(files_ls)
    eeg_filepath = files_ls{fi};
    [file_dir, name, ext] = fileparts(eeg_filepath);
    disp(['Processing file: ', eeg_filepath]);
    % Check if the file is a .TRC file
    if ~strcmp(ext, '.TRC')
        error('File is not a .TRC file');
    end

    file_dir_parts = strsplit(file_dir, '\');
    new_name = strcat(file_dir_parts{end-2}, '_', file_dir_parts{end}, '_', name);
    new_name = strrep(new_name, ' ', '_');
    new_name = strrep(new_name, '-', '_');
    new_name = strrep(new_name, '(', '_');
    new_name = strrep(new_name, ')', '_');
    new_name = strrep(new_name, '.', '_');

    disp(['New name: ', new_name]);

    % Load the TRC file

    hdr = ft_read_header(eeg_filepath{1});
    fs = hdr.Fs;
    nr_samples = hdr.nSamples;
    if fs < 1000
        {subjName, fs}
        error('Sampling Rate under 1 kHz');
    end

    %% Fieldtrip montage
    cfg = [];
    cfg.dataset = eeg_filepath;
    data_orig = ft_preprocessing(cfg);
    hdrBV = ft_fetch_header(data_orig);
    for chi = 1:length(hdrBV.label)
        chname = hdrBV.label{chi};
        chname = strrep(chname, ' ', '');
        if ~isnan(str2double(hdrBV.label{chi}))
            hdrBV.label{chi} = strcat('G', chname);
        end
    end

    brainVisionDataPath = "BrainVision_Output\";mkdir(brainVisionDataPath);
    brainVisionFile_Filepath = strcat(brainVisionDataPath, new_name, '.vhdr');
    brainVisionFile_Filepath = brainVisionFile_Filepath{1};

    ft_write_data(brainVisionFile_Filepath, data_orig.trial{1}, 'header', hdrBV)
end
