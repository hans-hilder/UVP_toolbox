%% Create the sample file of a project
% Create the sample file for all sequences
% For SeaExplorer, for SeaGlider and for BGC-argo float
%
% 20250929 In Progress, updates to allow for ALR (Auto-sub) data. 
%
% !!! WARNINGS !!!
% !!! the code is case sensitive !!!
% !!! Close UVPapp before using the code !!!
%
% ------ ALL platforms ----------
% MERGE the sequences first using UVPapp (if necessary).
% For floats, the profiles must be merged first and the parking then
% For gliders, there is no parking and there might not be any merging need
%
%
% ----- SeaExplorer project -----
% The project must contain "sea" in the name.
% The meta data are extracted from the sequence and a nav file located in
% the doc folder of the project.
% The meta data folder must start with "SEA" and the sn of the glider,
% "SEA###*".
% The files must be located directly in ccu/logs/*raw*.#.gz, with # the nb of the
% yo.
% example:
% uvp6_sn000003lp_2021_sea002_m495\doc\SEA002_m495_full\ccu\logs\sea002.495.pld1.raw.7.gz
%
%
% ----- SeaGlider project -----
% The project must contain "SG" in the name.
% The meta data are extracted from the sequence and a nav file located in
% the doc folder of the project.
% The meta data folder must be called "SG###_nc_files", with ### the sn of
% the glider.
% The files in it are called "p[sn]####.nc", with #### the nb of the yo.
% There must be placed in an other folder (called nc_files for example).
% The only file remaining that will be used is a unique summary nc file of
% type : sg644_SG644_20230817_PF_timeseries.nc
% example:
% uvp6_sn000006lp_2021_SG150_PolarFront\doc\SG150_PolarFront_arctos\sg150_20210516_150_019_timeseries.nc
%
%
% ----- BGC-Argo float project -----
% For recovered BGC float uvp6 data.
% The project name must contain the WMO number in the name 
% (uvp6_sn000110lp_YYYY_WMO6904139_recovery). YYYY is the year of the
% deployment of the float. Recovery indicates that the project contains
% recovered data.
% The metadata are extraceted from the sequence and netcdf argo files (one
% per profile) present in a folder starting by float and ending by the 
% WMOnumber "float_*_#######"
% This folder must be placed in the doc folder of the project.
% The synthetic profile files must be located directly in it. The filenames are S*6904139_###.nc where 
% 6904139 is the WMO number and ### the number of the profile. The S prefix indicates that they are synthetic files. 
% The files used are the individual profile files 
% from https://dataselection.euro-argo.eu/ NetCDF Argo original
% Merge sequences rules : one sequence per ascent, one parking sequence
% between two ascent
% example:
% uvp6_sn000110lp_2021_WMO6904139_recovery\doc\float_meta_WMO6904139\SD6904139_007.nc
%
%
% -- CTD files --
% The CTD files for EcoPART are created using the data from the vector
% Due to a bug from EcoPART, after the process, move those files into a new ctd_data_cnv folder in
% the project in order to import them
% For SeaGlider, the ctd files are all the same
%
%
% -- Noise detection --
% Noise detection is done on the black 2pix
%
% 
% use Mapping Toolbox 
%
% camille catalano 11/2020

clear all
close all
warning('on')

disp('------------------------------------------------------')
disp('------------- uvp6 sample creator --------------------')
disp('------------------------------------------------------')
disp('')
disp('WARNING : Work only for seaexplorer project, seaglider project and BGC project')
disp('Read the help of the script for information about the needed project structure')
disp('')


%% inputs and its QC
% process params
%parking_pressure_diff : pressure difference to identify parkings
parking_pressure_diff = 70; % with margins
%deep_black_limit : depth where the black is considered only from the instrument
deep_black_limit = 100; %80m to be sure


% select the project
disp('Select UVP project folder ')
project_folder = uigetdir('',['Select UVP project folder']);
disp('---------------------------------------------------------------')
disp(['Project folder : ', project_folder])
disp('---------------------------------------------------------------')

% detection seaexplorer or seaglider in name
if contains(project_folder, 'sea')
    disp('SeaExplorer project')
    vector_type = 'SeaExplorer';
elseif contains(project_folder, 'SG')
    disp('SeaGlider project')
    vector_type = 'SeaGlider';
elseif contains(project_folder, 'WMO')
    disp('BGC float project')
    vector_type = 'float';
elseif ~isempty(dir(fullfile(project_folder, 'doc', 'alr_meta_sn*')))
    disp('ALR project')
    vector_type = 'ALR';
else
    warning('Only seaexplorer, seaglider, float, and ALR project are supported')
    vector_type = input('Is it a SeaExplorer (se), a SeaGlider (sg), a float (fl) project, or and ALR (alr) project ? ([se]/sg/fl/alr) ','s');
    if isempty(vector_type) || strcmp(vector_type,'se')
        vector_type = 'SeaExplorer';
    elseif strcmp(vector_type, 'sg')
        vector_type = 'SeaGlider';
    elseif strcmp(vector_type, 'fl')
        vector_type = 'float';
    elseif strcmp(vector_type, 'alr')
        vector_type = 'ALR';
    else
        error('ERROR : the project is not a seaexplorer or seaglider project')
    end
    
end

% detection meta in doc
[meta_data_folder, vector_sn] = DetectionVectorMetaFile(project_folder, vector_type);

% detection if sample file already exist
samples_filename = regexp(project_folder, filesep, 'split');
samples_filename = [samples_filename{1,end}(1:5) 'header' samples_filename{1,end}(5:end) '.txt'];
sample_filename = fullfile(project_folder, 'meta', samples_filename);
list_in_meta = dir(fullfile(project_folder, 'meta', '*.txt'));
idx = find(strcmp({list_in_meta.name}, samples_filename) ==1);
if ~isempty(idx)
    warning('There is already a meta data file in \meta. IT WILL BE ARCHIVED')
    archived_old_meta = input('Continue ? ([n]/y) ','s');
    if isempty(archived_old_meta) || archived_old_meta == 'n'
        error('ERROR : Process has been aborted')
    end
    old_name = fullfile(list_in_meta(idx).folder, list_in_meta(idx).name);
    new_name = [old_name(1:end-4) '_' datestr(now, 'YYYYmmDD-hhMMss') old_name(end-3:end)];
    movefile(old_name, new_name);
end
disp('---------------------------------------------------------------')


%% get cruise info
try
    cruise_file = fullfile(project_folder, 'config', 'cruise_info.txt');
    fid = fopen(cruise_file);
    tline = fgetl(fid);
    tline = fgetl(fid);
    cruise = tline(7:end);
    fclose(fid);
catch
    cruise = 'unknown';
end

%% get meta data from dat file
% list of sequences: without "UsedForMerged"
list_of_sequences = dir(fullfile(project_folder, 'raw', '20*'));
idx = cellfun('isempty',regexp({list_of_sequences.name}, 'UsedForMerge'));
list_of_sequences = list_of_sequences(idx);

% get metadata from each sequence data file
disp('Get data from all sequences...')
disp(['The instrumental noise is evaluated under ' num2str(deep_black_limit) 'm'])
seq_nb_max = length(list_of_sequences);
aa_list = zeros(1, seq_nb_max);
exp_list = zeros(1, seq_nb_max);
volimage_list = zeros(1, seq_nb_max);
pixelsize_list = zeros(1, seq_nb_max);
start_idx_list = zeros(1, seq_nb_max);
end_idx_list = zeros(1, seq_nb_max);
start_time_list = zeros(1, seq_nb_max);
stop_time_list = zeros(1, seq_nb_max);
profile_type_list = strings(1, seq_nb_max);
sample_type_list = strings(1, seq_nb_max);
integration_time_list = NaN(1, seq_nb_max);

% Addition: cache per-sequence time & depth for ALR-driven matching later
uvp_time_series  = cell(1, seq_nb_max);  % datenum time per UVP sequence
uvp_depth_series = cell(1, seq_nb_max);  % depth per UVP sequence

for seq_nb = 1:seq_nb_max
    % get hw conf data
    seq_dat_file = fullfile(list_of_sequences(seq_nb).folder, list_of_sequences(seq_nb).name, [list_of_sequences(seq_nb).name, '_data.txt']);
    [hw_line, ~, ~] = Uvp6ReadMetalinesFromDatafile(seq_dat_file);
    [sn,day,light,shutter,threshold,volume,gain,pixel,Aa,Exp] = Uvp6ReadMetadataFromhwline(hw_line);
    
    % volimage;aa;exp,pixelsize
    aa_list(seq_nb) = Aa/1000000;
    exp_list(seq_nb) = Exp;
    volimage_list(seq_nb) = volume;
    pixelsize_list(seq_nb) = pixel;
    
    % read data from dat file
    [data, meta] = Uvp6DatafileToArray(seq_dat_file);
    [time_data, depth_data, raw_nb, black_nb, ~, image_status] = Uvp6ReadDataFromDattable(meta, data);
    black_nb = [depth_data time_data black_nb];
    I = isnan(black_nb(:,3));
    black_nb(I,:) = [];
    
    % Addition: store per-sequence time & depth
    uvp_time_series{seq_nb}  = time_data;
    uvp_depth_series{seq_nb} = depth_data;

    % detection of ascent profile (or descent or parking)
    if strcmp(vector_type, 'float') && (abs(depth_data(end) - depth_data(1)) < parking_pressure_diff)
        profile_type = 'p';
        sample_type = 'T';
        integration_time_list(seq_nb) = 1;
    elseif depth_data(end) < depth_data(1)
        profile_type = 'a';
        black_nb = flip(black_nb);
        sample_type = 'P';
    else
        profile_type = 'd';
        sample_type = 'P';
    end
    profile_type_list(seq_nb) = profile_type;
    sample_type_list(seq_nb) = sample_type;
    
    % detection auto first image by using default method
    %{
    % code for using 1pix black
    % test if black 1pix is all 0
    if any(black_nb(:,3))
        first_black = black_nb(:,3);
    else
        first_black = black_nb(:,4);
    end
    %}
    % Use black 2pix instead
    first_black = black_nb(:,4);
    % detection auto first image by using default method
    [Zusable] = UsableDepthLimit(black_nb(:,1), first_black, deep_black_limit);

    % datetime first image
    if isnan(Zusable)
        start_idx_list(seq_nb) = nan; % uvpapp is in python and start at index 0 for the image number
        end_idx_list(seq_nb) = nan;
        start_time_list(seq_nb) = time_data(1);
        stop_time_list(seq_nb) = time_data(end);
    else
        Zusable_idx = find(depth_data>=Zusable);
        start_idx_list(seq_nb) = Zusable_idx(1) - 1; % uvpapp is in python and start at index 0 for the image number
        end_idx_list(seq_nb) = Zusable_idx(end) - 1;
        start_time_list(seq_nb) = time_data(Zusable_idx(1));
        stop_time_list(seq_nb) = time_data(Zusable_idx(end));
    end
    
    disp(['Sequence ' list_of_sequences(seq_nb).name ' done.'])
end
disp('---------------------------------------------------------------')

%% get lat-lon from vector meta data
% seaeplorer/seaglider dependant
% go through meta files and look for start time of sequences
% assume that sequences AND meta files are chronologicaly ordered
disp('Process the vector meta data....')

if strcmp(vector_type, 'float')
    ref_time_list = stop_time_list;
else
    ref_time_list = start_time_list;
end

if ~strcmp(vector_type, 'ALR')
    [lon_list, lat_list, yo_list, samples_names_list, vector_filenames_list] = ...
        GetMetaFromVectorMetaFile(vector_type, meta_data_folder, ref_time_list, list_of_sequences, profile_type_list, cruise);
else
    % Addition: ALR-driven matching (±10s) against cached UVP times
    [lon_list, lat_list, yo_list, samples_names_list, vector_filenames_list, ...
     start_idx_list, end_idx_list, start_time_list, assigned_uvp_seq_idx, ...
     alr_plot_time, alr_plot_depth, skipped_count, total_alr] = ...
        GetMetaFromVectorMetaFile(vector_type, meta_data_folder, ref_time_list, ...
                                  list_of_sequences, profile_type_list, cruise, ...
                                  uvp_time_series, uvp_depth_series, start_idx_list, end_idx_list);
    
    % Addition: shrink all per-sequence UVP meta arrays to per-sample length by mapping
    %           (reuse the per-UVP-sequence metadata for each ALR-derived sample)
    aa_list        = aa_list(assigned_uvp_seq_idx);
    exp_list       = exp_list(assigned_uvp_seq_idx);
    volimage_list  = volimage_list(assigned_uvp_seq_idx);
    pixelsize_list = pixelsize_list(assigned_uvp_seq_idx);
    
    % Addition: the 'filename' (UVP sequence folder) should follow the chosen UVP sequence per row
    list_of_sequences = list_of_sequences(assigned_uvp_seq_idx);  % now length = #kept ALR samples
    
    % Addition: set profile/sample type = ALR suffix letter, and yo_list already set inside function
    profile_type_list = strings(1, numel(samples_names_list));  % reset to per-sample sizing
    sample_type_list  = strings(1, numel(samples_names_list));
    for i = 1:numel(samples_names_list)
        % parse suffix letter from ALR filename (stored in vector_filenames_list)
        fname = char(vector_filenames_list(i));
        tok = regexp(fname, '_([A-Za-z])\d+\.nc$', 'tokens', 'once');
        if ~isempty(tok)
            letter = tok{1};
        else
            letter = 'na';
        end
        profile_type_list(i) = string(letter);   % Addition
        sample_type_list(i)  = string(letter);   % Addition
    end
    
    % Addition: redefine seq_nb_max to the number of kept ALR samples
    seq_nb_max = numel(samples_names_list);
    
    % Addition: after building everything, report skipped count
    disp(['Matching UVP sequence times were not found for ' num2str(skipped_count) ...
          ' of ' num2str(total_alr) ' samples.'])
end

disp('---------------------------------------------------------------')


%% Addition: combined diagnostic plot (UVP vs ALR time–depth)

try
    % Get path of the currently open script (robust to Editor temp copies)
    if ~isdeployed && usejava('desktop')
        thisfile = matlab.desktop.editor.getActiveFilename;
    else
        thisfile = mfilename('fullpath');
    end

    if isempty(thisfile)
        scriptDir = pwd;
    else
        scriptDir = fileparts(thisfile);
    end

    outdir = fullfile(scriptDir, 'output');
    if ~exist(outdir, 'dir')
        mkdir(outdir);
    end
    figure('Visible','off'); hold on; grid on;
    % Plot all UVP sequences (thin line)
    for s = 1:numel(uvp_time_series)
        if isempty(uvp_time_series{s}) || isempty(uvp_depth_series{s}), continue; end
        plot(uvp_time_series{s}, uvp_depth_series{s}, '-', 'LineWidth', 0.5); % UVP
    end
    % Overlay all kept ALR points
    if exist('alr_plot_time','var') && ~isempty(alr_plot_time)
        plot(alr_plot_time, alr_plot_depth, '.', 'MarkerSize', 6); % ALR
    end
    set(gca, 'YDir', 'reverse');
    datetick('x','keeplimits');
    xlabel('Time'); ylabel('Depth (m)');
    legend({'UVP','ALR'}, 'Location','best');
    title('UVP vs ALR time–depth (±10 s match window)');
    print(fullfile(outdir, 'uvp_alr_timedepth.png'), '-dpng', '-r150');
    close(gcf);
    disp(['Saved diagnostic plot to: ' fullfile(outdir, 'uvp_alr_timedepth.png')])
catch ME
    disp(['Plotting skipped: ' ME.message])
end


%%

N = numel(samples_names_list);      % number of ALR-matched samples
seq_nb_max = N;                     % the writer loop will iterate N rows

toRow = @(x) reshape(x, 1, []);     % helper to coerce to row vectors

% Map per-UVP-sequence metadata to the chosen UVP sequence for each ALR row
aa_list        = toRow(aa_list(assigned_uvp_seq_idx));
exp_list       = toRow(exp_list(assigned_uvp_seq_idx));
volimage_list  = toRow(volimage_list(assigned_uvp_seq_idx));
pixelsize_list = toRow(pixelsize_list(assigned_uvp_seq_idx));

% Integration time: reuse per-sequence values per matched ALR row, else NaN
if exist('integration_time_list','var') && ~isempty(integration_time_list)
    integration_time_list = toRow(integration_time_list(assigned_uvp_seq_idx));
else
    integration_time_list = NaN(1, N);
end

% These are already per-ALR row; just ensure 1×N shape
lat_list              = toRow(lat_list);
lon_list              = toRow(lon_list);
yo_list               = toRow(yo_list);
samples_names_list    = toRow(samples_names_list);      % string array OK
vector_filenames_list = toRow(vector_filenames_list);   % string array OK
start_idx_list        = toRow(start_idx_list);
end_idx_list          = toRow(end_idx_list);
start_time_list       = toRow(start_time_list);

% Profile/sample type letters (from ALR suffix) should be per-ALR row
profile_type_list = toRow(profile_type_list);
sample_type_list  = toRow(sample_type_list);

% UVP sequence struct array must be reindexed and shaped to 1×N
list_of_sequences = list_of_sequences(:).';

% (Optional) quick assert during development:
% assert(all([N==numel(lat_list), N==numel(lon_list), N==numel(yo_list), ...
%     N==numel(samples_names_list), N==numel(vector_filenames_list), ...
%     N==numel(start_idx_list), N==numel(end_idx_list), N==numel(start_time_list), ...
%     N==numel(aa_list), N==numel(exp_list), N==numel(volimage_list), ...
%     N==numel(pixelsize_list), N==numel(profile_type_list), N==numel(sample_type_list), ...
%     N==numel(integration_time_list)]), 'Array size mismatch after normalization.');
% -------------------------------------------------------------------------


%% sample file writing
disp('Creating the sample file...')
% file creation

sample_file = fopen(sample_filename,'w','n','windows-1252');
    
% add header
line = ['cruise;ship;filename;profileid;'...
    'bottomdepth;ctdrosettefilename;latitude;longitude;'...
    'firstimage;volimage;aa;exp;'...
    'dn;winddir;windspeed;seastate;'...
    'nebuloussness;comment;endimg;yoyo;'...
    'stationid;sampletype;integrationtime;argoid;'...
    'pixelsize;sampledatetime'];
fprintf(sample_file,'%s\n',line);

% write samples lines
% one sample by sequence
for seq_nb = 1:seq_nb_max
    % lat format
    % signe = sign(lat_list(seq_nb));
    % lat_deg = fix(lat_list(seq_nb) * signe);
    % lat_min = fix(rem(lat_list(seq_nb) * signe,1)*60);
    % lat_sec = round(rem(rem(lat_list(seq_nb) * signe,1)*60,1)*60);
    % if lat_sec == 60
    %     lat_sec = 0;
    %     lat_min = lat_min + 1;
    % end
    % if lat_min == 60
    %     lat_min = 0;
    %     lat_deg = lat_deg + 1;
    % end
    % if signe == -1
    %     lat = ['-' num2str(lat_deg) '°' num2str(lat_min, '%02.f') ' ' num2str(lat_sec, '%02.f')];
    % else
    %     lat = [num2str(lat_deg) '°' num2str(lat_min, '%02.f') ' ' num2str(lat_sec, '%02.f')];
    % end
    % % lon format
    % signe = sign(lon_list(seq_nb));
    % lon_deg = fix(lon_list(seq_nb) * signe);
    % lon_min = fix(rem(lon_list(seq_nb) * signe,1)*60);
    % lon_sec = round(rem(rem(lon_list(seq_nb) * signe,1)*60,1)*60);
    % if lon_sec == 60
    %     lon_sec = 0;
    %     lon_min = lon_min + 1;
    % end
    % if lon_min == 60
    %     lon_min = 0;
    %     lon_deg = lon_deg + 1;
    % end
    % if signe == -1
    %     lon = ['-' num2str(lon_deg) '°' num2str(lon_min, '%02.f') ' ' num2str(lon_sec, '%02.f')];
    % else
    %     lon = [num2str(lon_deg) '°' num2str(lon_min, '%02.f') ' ' num2str(lon_sec, '%02.f')];
    % end
    
    % ctd files names
    ctd_filesnames = [char(samples_names_list(seq_nb)) '.ctd'];
    % line to write
    seq_line = [cruise ';'...
                vector_sn ';'... 
                list_of_sequences(seq_nb).name ';'...
                char(samples_names_list(seq_nb)) ';'...
                'nan' ';'...
                ctd_filesnames ';'... 
                num2str(lat_list(seq_nb)) ';'...
                num2str(lon_list(seq_nb)) ';'...
                num2str(start_idx_list(seq_nb)) ';'... 
                num2str(volimage_list(seq_nb)) ';'... 
                num2str(aa_list(seq_nb)) ';'... 
                num2str(exp_list(seq_nb)) ';'...
                '' ';'... 
                'nan' ';'... 
                'nan' ';'... 
                'nan' ';'...
                'nan' ';'... 
                '' ';'... 
                num2str(end_idx_list(seq_nb)) ';'...
                '' ';'...
                num2str(yo_list(seq_nb)) ';'...
                char(sample_type_list(seq_nb)) ';'...
                num2str(integration_time_list(seq_nb)) ';'...
                char(vector_filenames_list(seq_nb)) ';'...
                num2str(pixelsize_list(seq_nb)) ';'... 
                datestr(start_time_list(seq_nb), 'yyyymmdd-HHMMss')];
    fprintf(sample_file, '%s\n', seq_line);
end
fclose(sample_file);

disp(['Sample file created : ' sample_filename])
disp('------------------------------------------------------')
disp('end of process')
disp('------------------------------------------------------')

