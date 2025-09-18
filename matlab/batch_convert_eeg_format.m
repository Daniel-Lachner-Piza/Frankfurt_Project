%% ========================================================================
% BATCH EEG FILE FORMAT CONVERTER
% ========================================================================
%
% DESCRIPTION:
%   This script performs batch conversion of EEG files from one format to
%   another. Primarily designed for converting Micromed .trc files to
%   BrainVision (.vhdr/.vmrk/.eeg) or EDF (.edf) format. The script:
%
%   1. Recursively searches for EEG files with specified extension
%   2. Validates files based on minimum sampling rate (1000 Hz)
%   3. Converts valid files while preserving directory structure
%   4. Generates detailed logs of conversion results
%   5. Handles channel name formatting for compatibility
%
% FEATURES:
%   - Recursive directory scanning
%   - Sampling rate validation (minimum 1000 Hz threshold)
%   - Automatic directory structure creation
%   - Progress tracking and error handling
%   - Comprehensive logging (success, failure, insufficient sampling rate)
%   - Channel name sanitization for format compatibility
%
% SUPPORTED INPUT FORMATS:
%   - Micromed .trc files (primary tested format)
%   - Any format supported by FieldTrip's ft_read_header function
%
% SUPPORTED OUTPUT FORMATS:
%   - BrainVision format (.vhdr/.vmrk/.eeg) - Recommended for EEG analysis
%   - European Data Format (.edf) - Standard medical data format
%
% AUTHOR: Daniel Lachner-Piza
% DATE: 08.09.2025
% VERSION: 1.1
% CONTACT: daniellachner@gmail.com
%
% DEPENDENCIES:
%   - MATLAB R2023b or later
%   - FieldTrip toolbox (version 20221121 or compatible)
%     Available at: https://www.fieldtriptoolbox.org/
%
% INSTALLATION:
%   1. Download and install FieldTrip toolbox
%   2. Update the ftPath variable to point to your FieldTrip installation
%   3. Configure input/output paths in the configuration section
%
% USAGE:
%   1. Configure paths in the "Configuration Parameters" section below
%   2. Set input file extension (in_eeg_ext) and output format (out_eeg_ext)
%   3. Run the script: batch_convert_eeg_format
%   4. Monitor progress in command window
%   5. Check generated CSV files for detailed conversion results
%
% OUTPUT FILES:
%   Converted EEG Files:
%   - Organized in patient-specific subdirectories
%   - Named with standardized convention: [ParentDir_OriginalName]
%
%   Log Files (saved to output directory):
%   - Patients_Correct_SamplingRate.csv: Successfully processed files
%   - Patients_Insufficient_SamplingRate.csv: Files below 1000 Hz threshold
%   - Failed_Conversions.csv: Files that encountered conversion errors
%
% PERFORMANCE NOTES:
%   - Processing time depends on file size and number of files
%   - Large files (>2GB) may require significant memory and processing time
%   - Progress is displayed as percentage completion in command window
%
% TROUBLESHOOTING:
%   - Ensure FieldTrip is properly installed and on MATLAB path
%   - Check file permissions for input and output directories
%   - Verify sufficient disk space for converted files
%   - See Failed_Conversions.csv for files that couldn't be processed
%
% CHANGELOG:
%   v1.1 (07.09.2025): Enhanced documentation and error handling
%   v1.0 (Initial): Basic batch conversion functionality
%
% ========================================================================

% Clean workspace and initialize environment
clear all; close all; clc;

%% ========================================================================
% FIELDTRIP TOOLBOX INITIALIZATION
% ========================================================================
% Initialize FieldTrip toolbox for EEG data processing
% FieldTrip is required for reading/writing various EEG file formats

% Get current script path for relative path calculations
[path, ~, ~] = fileparts(mfilename('fullpath'));
cutIdx = strfind(path, '\');

% Configure FieldTrip path - UPDATE THIS PATH TO MATCH YOUR INSTALLATION
ftPath = strcat('C:\Users\HFO\Documents\Postdoc_Calgary\Research\fieldtrip-20221121');
addpath(ftPath);
ft_defaults;  % Initialize FieldTrip with default settings

fprintf('FieldTrip toolbox initialized successfully.\n');

%% ========================================================================
% CONFIGURATION PARAMETERS
% ========================================================================
% Modify these parameters according to your data organization and requirements

% Output directory for converted EEG files
% NOTE: Directory will be created if it doesn't exist
outputPath = "D:\EDF_EEG_Files\";
%outputPath = "I:\Frankurt_EDF_Data\";
mkdir(outputPath);

% Root directory to search for input EEG files (searches recursively)
%eegs_search_dir = "D:\ToConvert\";
eegs_search_dir = "D:\";

% Input file format extension (what files to search for)
% Supported: .trc (Micromed), or any format readable by FieldTrip
in_eeg_ext = '.trc';

% Output file format extension (what format to convert to)
% Tested formats:
%   - '.vhdr' for BrainVision format (creates .vhdr/.vmrk/.eeg files)
%   - '.edf' for European Data Format
out_eeg_ext = '.edf';

% Minimum sampling rate threshold (Hz)
% Files below this threshold will be logged but not converted
min_sampling_rate = 1000;

fprintf('Configuration loaded:\n');
fprintf('  Input directory: %s\n', eegs_search_dir);
fprintf('  Output directory: %s\n', outputPath);
fprintf('  Input format: %s\n', in_eeg_ext);
fprintf('  Output format: %s\n', out_eeg_ext);
fprintf('  Minimum sampling rate: %d Hz\n', min_sampling_rate);

%% ========================================================================
% MAIN PROCESSING PIPELINE
% ========================================================================

% Step 1: Validate EEG files and categorize by sampling rate
fprintf('\n=== STEP 1: Validating EEG files ===\n');
[patients_wrong_fs_ls, patients_correct_fs_ls] = validate_eeg(eegs_search_dir, in_eeg_ext, outputPath, min_sampling_rate);

% Step 2: Convert files with adequate sampling rate
fprintf('\n=== STEP 2: Converting valid EEG files ===\n');
run_conversion(patients_correct_fs_ls, out_eeg_ext, outputPath, min_sampling_rate);

fprintf('\n=== BATCH CONVERSION COMPLETE ===\n');
fprintf('Check the following files in %s for detailed results:\n', outputPath);
fprintf('  - Patients_Correct_SamplingRate.csv\n');
fprintf('  - Patients_Insufficient_SamplingRate.csv\n');
fprintf('  - Failed_Conversions.csv\n');


%% ========================================================================
% VALIDATE_EEG - Categorize EEG files by sampling rate adequacy
% ========================================================================
%
% DESCRIPTION:
%   Scans all EEG files in the specified directory and categorizes them
%   based on sampling rate criteria. Creates CSV files listing files that
%   meet or don't meet the minimum sampling rate requirement.
%
% INPUTS:
%   eegs_search_dir    - String: Root directory to search for EEG files
%   in_eeg_ext         - String: File extension to search for (e.g., '.trc')
%   outputPath         - String: Directory path for output CSV files
%   min_sampling_rate  - Numeric: Minimum required sampling rate (Hz)
%
% OUTPUTS:
%   patients_wrong_fs_ls   - Cell array: Files with insufficient sampling rate
%   patients_correct_fs_ls - Cell array: Files with adequate sampling rate
%
% SIDE EFFECTS:
%   Creates two CSV files in outputPath:
%   - Patients_Correct_SamplingRate.csv: Files >= min_sampling_rate
%   - Patients_Insufficient_SamplingRate.csv: Files < min_sampling_rate
%
% PERFORMANCE:
%   - Only reads file headers (fast operation)
%   - Displays progress percentage during processing
%   - Skips processing if CSV files already exist (resume capability)
%
function [patients_wrong_fs_ls, patients_correct_fs_ls] = validate_eeg(eegs_search_dir, in_eeg_ext, outputPath, min_sampling_rate)

% Discover all EEG files in the search directory tree
fprintf('Searching for %s files in: %s\n', in_eeg_ext, eegs_search_dir);
files_ls = get_eeg_filepaths(eegs_search_dir, in_eeg_ext);
fprintf('Found %d EEG files to validate.\n', length(files_ls));

% Define paths for output CSV files that track validation results
patients_correct_fs_fpath = strcat(outputPath, 'Patients_Correct_SamplingRate.csv');
patients_wrong_fs_fpath = strcat(outputPath, 'Patients_Insufficient_SamplingRate.csv');

% Initialize categorization arrays
patients_wrong_fs_ls = {};    % Files with sampling rate < min_sampling_rate
patients_correct_fs_ls = {};  % Files with sampling rate >= min_sampling_rate

% Check if validation has already been performed (resume capability)
if isfile(patients_correct_fs_fpath) && isfile(patients_wrong_fs_fpath)
    fprintf('Validation CSV files already exist. Loading previous results...\n');
    patients_correct_fs_ls = readcell(patients_correct_fs_fpath,"Delimiter",",");
    patients_wrong_fs_ls = readcell(patients_wrong_fs_fpath,"Delimiter",",");
    fprintf('Loaded %d files with correct sampling rate.\n', length(patients_correct_fs_ls));
    fprintf('Loaded %d files with insufficient sampling rate.\n', length(patients_wrong_fs_ls));
    return
end

% Process each EEG file to determine sampling rate adequacy
N = length(files_ls);
fprintf('Starting validation of %d files...\n', N);

for fi = 1:N
    eeg_filepath = files_ls{fi};

    try
        % Read only the header to check sampling rate (efficient)
        hdr = ft_read_header(eeg_filepath);
        fs = hdr.Fs;  % Sampling frequency in Hz

        % Categorize file based on sampling rate threshold
        if fs < min_sampling_rate
            % Insufficient sampling rate - add to exclusion list
            patients_wrong_fs_ls = cat(1, patients_wrong_fs_ls, eeg_filepath);
            fprintf('  SKIP: %s (fs = %.1f Hz < %d Hz)\n', eeg_filepath, fs, min_sampling_rate);
        else
            % Adequate sampling rate - add to conversion list
            patients_correct_fs_ls = cat(1, patients_correct_fs_ls, eeg_filepath);
            fprintf('  OK: %s (fs = %.1f Hz)\n', eeg_filepath, fs);
        end

    catch ME
        % Handle files that cannot be read
        fprintf('  ERROR reading header: %s - %s\n', eeg_filepath, ME.message);
        patients_wrong_fs_ls = cat(1, patients_wrong_fs_ls, eeg_filepath);
    end

    % Display progress every 10 files or at completion
    if mod(fi, 10) == 0 || fi == N
        progress = round((fi / N) * 100, 2);
        fprintf('Validation Progress: %.2f%% (%d/%d files)\n', progress, fi, N);
    end
end

% Save validation results to CSV files for future reference and analysis
fprintf('Saving validation results...\n');
writecell(patients_correct_fs_ls, patients_correct_fs_fpath);
writecell(patients_wrong_fs_ls, patients_wrong_fs_fpath);

fprintf('Validation complete:\n');
fprintf('  Files with adequate sampling rate: %d\n', length(patients_correct_fs_ls));
fprintf('  Files with insufficient sampling rate: %d\n', length(patients_wrong_fs_ls));

end

%% ========================================================================
% RUN_CONVERSION - Execute batch EEG file format conversion
% ========================================================================
%
% DESCRIPTION:
%   Performs the actual conversion of EEG files from input format to output
%   format. Only processes files that meet the sampling rate requirements.
%   Handles file organization, error tracking, and progress reporting.
%
% INPUTS:
%   patients_correct_fs_ls  - Cell array: list of files to process
%   out_eeg_ext             - String: Output file extension (e.g., '.edf', '.vhdr')
%   outputPath              - String: Base directory for converted files
%   min_sampling_rate       - Numeric: Minimum required sampling rate (Hz)
%
% OUTPUTS:
%   None (writes converted files to disk and creates failure log)
%
% SIDE EFFECTS:
%   - Creates converted EEG files in organized directory structure
%   - Generates Failed_Conversions.csv for files that couldn't be processed
%   - Displays detailed progress information
%   - Preserves original directory structure in output
%
% ERROR HANDLING:
%   - Individual file conversion errors are caught and logged
%   - Processing continues even if individual files fail
%   - Failed files are recorded in CSV for later investigation
%
function run_conversion(patients_correct_fs_ls, out_eeg_ext, outputPath, min_sampling_rate)

% Discover all EEG files for conversion (processing in reverse order)
% Note: Processing in reverse order can be helpful for debugging largest/newest files first
files_ls = flip(patients_correct_fs_ls);

% Initialize tracking for failed conversions
failed_conversions_ls = {};

% Process each file for conversion
N = length(files_ls);
fprintf('Starting conversion of %d EEG files...\n', N);

for fi = 1:N
    eeg_filepath = files_ls{fi};

    try
        % Attempt to convert the current file
        fprintf('Converting file %d/%d: %s\n', fi, N, eeg_filepath);
        convert_to_new_format(eeg_filepath, out_eeg_ext, outputPath, min_sampling_rate);
        fprintf('  SUCCESS: Conversion completed.\n');

    catch ME
        % Log conversion failures but continue processing other files
        failed_conversions_ls = cat(1, failed_conversions_ls, eeg_filepath);
        fprintf('  ERROR: Conversion failed - %s\n', ME.message);
        fprintf('  File added to failure log: %s\n', eeg_filepath);
    end

    % Display progress every 5 files or at completion
    if mod(fi, 5) == 0 || fi == N
        progress = round((fi / N) * 100, 2);
        fprintf('Conversion Progress: %.2f%% (%d/%d files)\n', progress, fi, N);
    end
end

% Save list of failed conversions for later investigation
failed_conversions_fpath = strcat(outputPath, 'Failed_Conversions.csv');
writecell(failed_conversions_ls, failed_conversions_fpath);

fprintf('Conversion batch complete:\n');
fprintf('  Successfully processed: %d files\n', N - length(failed_conversions_ls));
fprintf('  Failed conversions: %d files\n', length(failed_conversions_ls));
fprintf('  See failure details in: %s\n', failed_conversions_fpath);
end

% ========================================================================
% CONVERT_TO_NEW_FORMAT - Convert individual EEG file to target format
% ========================================================================
%
% DESCRIPTION:
%   Converts a single EEG file from input format to the specified output
%   format. Handles directory structure creation, data processing, channel
%   name formatting, and file writing. Includes safeguards against
%   reprocessing existing files and low sampling rate data.
%
% INPUTS:
%   eeg_filepath      - String: Full path to the source EEG file
%   out_eeg_ext       - String: Target file extension (.edf, .vhdr, etc.)
%   outputPath        - String: Base output directory path
%   min_sampling_rate - Numeric: Minimum required sampling rate (Hz)
%
% OUTPUTS:
%   None (creates converted file(s) in organized directory structure)
%
% PROCESSING PIPELINE:
%   1. Generate standardized patient/file naming
%   2. Create patient-specific output directory structure
%   3. Check for existing converted files (skip if present)
%   4. Validate sampling rate meets requirements
%   5. Load complete EEG data using FieldTrip
%   6. Process and format channel names for compatibility
%   7. Write data in target format
%
% DIRECTORY ORGANIZATION:
%   Output files are organized as:
%   outputPath/[ParentDir]/[GrandparentDir]/[StandardizedFileName].[ext]
%   This preserves meaningful directory structure from original data
%
% CHANNEL NAME PROCESSING:
%   - Removes spaces from channel names
%   - Adds 'G' prefix to purely numeric channel names
%   - Ensures compatibility with analysis software
%
% PERFORMANCE CONSIDERATIONS:
%   - Skips files that already exist in output directory
%   - Only processes files meeting sampling rate requirements
%   - Loads entire file into memory (ensure sufficient RAM for large files)
%
function convert_to_new_format(eeg_filepath, out_eeg_ext, outputPath, min_sampling_rate)

% Generate standardized patient/file name for output consistency
pat_name = get_new_patient_name(eeg_filepath);

% Parse input file path to maintain directory structure organization
[file_dir, ~, ~] = fileparts(eeg_filepath);
folder_parts = split(file_dir, '\');

% Create patient-specific output directory structure
% Structure: outputPath/[Parent-1]/[Parent]/[filename]
% This preserves meaningful hierarchical organization from source
pat_output_path = strcat(outputPath, folder_parts(end-2), '\', folder_parts(end), '\');
if ~exist(pat_output_path, 'dir')
    mkdir(pat_output_path);
    fprintf('    Created output directory: %s\n', pat_output_path);
end

% Define complete output file path for the converted file
converted_eeg_fpath = strcat(pat_output_path, pat_name);
target_file_path = strcat(converted_eeg_fpath, out_eeg_ext);
target_file_path = target_file_path{1};  % Convert from cell array to string

% Skip conversion if output file already exists (avoid reprocessing)
if isfile(target_file_path)
    fprintf('    SKIP: Output file already exists: %s\n', target_file_path);
    return
end

% Read file header to validate sampling rate before full processing
fprintf('    Reading file header...\n');
hdr = ft_read_header(eeg_filepath);

% Enforce minimum sampling rate requirement
if hdr.Fs < min_sampling_rate
    fprintf('    SKIP: Sampling rate %.1f Hz < required %d Hz\n', hdr.Fs, min_sampling_rate);
    return
end

fprintf('    File validated (fs = %.1f Hz, %d channels, %d samples)\n', ...
    hdr.Fs, hdr.nChans, hdr.nSamples);

%% Load and process complete EEG data
fprintf('    Loading complete EEG data (this may take time for large files)...\n');

% Configure FieldTrip preprocessing to read entire file
cfg = [];
cfg.datafile = eeg_filepath;    % Source file path
cfg.headerfile = eeg_filepath;  % Header information (same file for most formats)

% Load all data into memory
all_data = ft_preprocessing(cfg);
fprintf('    Data loaded successfully.\n');

% Extract data components for processing
% Note: We store original labels for potential future debugging/analysis
% original_labels = hdr.label;          % Store original channel labels (for reference)
eeg_signals = all_data.trial{1};      % EEG signal matrix [channels x samples]
time_vector = all_data.time{1};       % Time vector corresponding to samples

fprintf('    Data matrix: %d channels × %d samples\n', size(eeg_signals));

%% Prepare data structure for output format
fprintf('    Preparing data for output format...\n');

% Create a copy of the data structure for format-specific modifications
output_data = all_data;
output_data.hdr.nSamples = size(eeg_signals, 2);
output_data.trial{1} = eeg_signals;
output_data.sampleinfo(2) = size(eeg_signals, 2);
output_data.time{1} = time_vector;

% Generate FieldTrip-compatible header for output format
output_hdr = ft_fetch_header(output_data);

%% Process channel names for output format compatibility
fprintf('    Processing channel names for format compatibility...\n');

for chi = 1:length(output_hdr.label)
    original_chname = output_hdr.label{chi};
    processed_chname = strrep(original_chname, ' ', '');  % Remove spaces

    % Add 'G' prefix to purely numeric channel names for EEG software compatibility
    % Many EEG analysis programs require non-numeric channel identifiers
    if ~isnan(str2double(original_chname))
        processed_chname = strcat('G', processed_chname);
        fprintf('      Channel renamed: %s → %s\n', original_chname, processed_chname);
    end

    output_hdr.label{chi} = processed_chname;
end

%% Write converted data to target format
fprintf('    Writing data to %s format...\n', out_eeg_ext);

% Use FieldTrip's format-agnostic writer to handle different output formats
% Supports: BrainVision (.vhdr), EDF (.edf), and other formats
ft_write_data(target_file_path, output_data.trial{1}, 'header', output_hdr);

fprintf('    Conversion completed: %s\n', target_file_path);
end

% ========================================================================
% GET_NEW_PATIENT_NAME - Generate standardized naming convention
% ========================================================================
%
% DESCRIPTION:
%   Creates a standardized patient/file identifier by combining hierarchical
%   directory information with the original filename. Ensures consistent
%   naming across the dataset and removes characters that could cause
%   filesystem or analysis software compatibility issues.
%
% INPUTS:
%   eeg_filepath - String: Full path to the source EEG file
%
% OUTPUTS:
%   new_name - String: Sanitized and standardized file identifier
%
% NAMING CONVENTION:
%   Format: [ParentDirectory]_[OriginalFilename]
%   Example: "Patient001_Session01_EEG_Recording.trc"
%         → "Patient001_Session01_EEG_Recording"
%
% CHARACTER SANITIZATION:
%   Replaces the following characters with underscores:
%   - Spaces (' ') → '_'
%   - Hyphens ('-') → '_'
%   - Parentheses ('(', ')') → '_'
%   - Periods ('.') → '_'
%
% RATIONALE:
%   - Maintains traceability to original file location
%   - Ensures cross-platform filesystem compatibility
%   - Prevents issues with analysis software that may not handle special characters
%   - Creates consistent naming for automated processing pipelines
%
function new_name = get_new_patient_name(eeg_filepath)
% Parse file path components
[file_dir, name, ~] = fileparts(eeg_filepath);  % Extract directory and filename (extension unused)
file_dir_parts = strsplit(file_dir, '\');      % Split directory path into components

% Combine parent directory with filename for unique identification
% This preserves hierarchical information while creating a flat naming scheme
new_name = strcat(file_dir_parts{end}, '_', name);

% Sanitize filename by replacing problematic characters with underscores
% This ensures compatibility across different filesystems and analysis software
char_replacements = {' ', '-', '(', ')', '.'};  % Characters to replace
for i = 1:length(char_replacements)
    new_name = strrep(new_name, char_replacements{i}, '_');
end

% Additional cleanup: remove multiple consecutive underscores for cleaner names
new_name = regexprep(new_name, '_+', '_');  % Replace multiple underscores with single
new_name = regexprep(new_name, '^_|_$', ''); % Remove leading/trailing underscores
end

% ========================================================================
% GET_EEG_FILEPATHS - Recursive EEG file discovery
% ========================================================================
%
% DESCRIPTION:
%   Performs recursive search through directory tree to locate all files
%   matching the specified EEG file extension. Returns complete file paths
%   suitable for batch processing operations.
%
% INPUTS:
%   eegs_search_dir - String: Root directory path for recursive search
%   eeg_ext         - String: File extension filter (e.g., '.trc', '.edf')
%
% OUTPUTS:
%   filePaths - Cell array of strings: Complete file paths to all matching files
%
% SEARCH BEHAVIOR:
%   - Searches recursively through all subdirectories
%   - Case-sensitive extension matching
%   - Returns full absolute paths for each discovered file
%   - No filtering by file size, modification date, or other attributes
%
% PERFORMANCE NOTES:
%   - Search time increases with directory depth and file count
%   - Large directory trees may take several minutes to scan
%   - Results are returned in filesystem-dependent order (not sorted)
%
% EXAMPLE USAGE:
%   files = get_eeg_filepaths('C:\Data\', '.trc');
%   fprintf('Found %d files\n', length(files));
%
% DEPENDENCIES:
%   - MATLAB's dir() function with recursive search pattern ('**\')
%   - fullfile() function for path construction
%
function filePaths = get_eeg_filepaths(eegs_search_dir, eeg_ext)
% Construct search pattern for recursive file discovery
search_pattern = strcat(eegs_search_dir, '**\*', eeg_ext);

% Execute recursive directory search
% The '**\' pattern tells dir() to search all subdirectories recursively
files = dir(search_pattern);

% Combine directory paths with filenames to create complete file paths
% This ensures all returned paths are absolute and ready for processing
filePaths = fullfile({files.folder}, {files.name});

% Convert to column cell array for consistent output format
filePaths = filePaths(:);
end
