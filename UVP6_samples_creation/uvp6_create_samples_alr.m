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
disp('WARNING : Work only for seaexplorer project, seaglider project, BGC, and ALR project')
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
    movefile(old_name, new_name, 'f');
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


%% Addition: combined diagnostic plot (UVP vs ALR time–depth + 10 s binned |Δdepth|)
try
    % Script directory
    if ~isdeployed && usejava('desktop')
        thisfile = matlab.desktop.editor.getActiveFilename;
    else
        thisfile = mfilename('fullpath');
    end

    if isempty(thisfile), scriptDir = pwd; else, scriptDir = fileparts(thisfile); end

    outdir = fullfile(scriptDir, 'output');
    if ~exist(outdir, 'dir'), mkdir(outdir); end

    % -------- Gather & normalize time/depth to datetime ----------
    % UVP: concatenate all sequences
    t_uvp = []; z_uvp = [];
    for s = 1:numel(uvp_time_series)
        if isempty(uvp_time_series{s}) || isempty(uvp_depth_series{s}), continue; end
        t_uvp = [t_uvp; uvp_time_series{s}(:)];
        z_uvp = [z_uvp; uvp_depth_series{s}(:)];
    end
    if ~isempty(t_uvp)
        if isnumeric(t_uvp)
            t_uvp = datetime(t_uvp, 'ConvertFrom', 'datenum');
        elseif ~isdatetime(t_uvp)
            error('UVP time format not recognized.');
        end
    end

    % ALR
    t_alr = []; z_alr = [];
    haveALR = exist('alr_plot_time','var') && ~isempty(alr_plot_time);
    if haveALR
        t_alr = alr_plot_time(:);
        z_alr = alr_plot_depth(:);
        if isnumeric(t_alr)
            t_alr = datetime(t_alr, 'ConvertFrom', 'datenum');
        elseif ~isdatetime(t_alr)
            error('ALR time format not recognized.');
        end
    end

    % -------- Build 10-second bins over full data extent ----------
    if ~isempty(t_uvp) || ~isempty(t_alr)
        candidates_min = datetime.empty(0,1);
        candidates_max = datetime.empty(0,1);
        if ~isempty(t_uvp)
            candidates_min(end+1,1) = min(t_uvp);
            candidates_max(end+1,1) = max(t_uvp);
        end
        if ~isempty(t_alr)
            candidates_min(end+1,1) = min(t_alr);
            candidates_max(end+1,1) = max(t_alr);
        end
        t_min = min(candidates_min);
        t_max = max(candidates_max);

        edges = (t_min:seconds(10):t_max+seconds(10)).';     % bin edges
        centers = edges(1:end-1) + seconds(5);               % bin centers
        nb = numel(edges)-1;
    else
        edges = datetime.empty; centers = datetime.empty; nb = 0;
    end

    % Mean depth per 10s bin for UVP and ALR
    uvp_bin_mean = nan(nb,1);
    alr_bin_mean = nan(nb,1);
    if nb > 0
        if ~isempty(t_uvp)
            b = discretize(t_uvp, edges);
            uvp_bin_mean = accumarray(b(~isnan(b)), z_uvp(~isnan(b)), [nb 1], @median, NaN);
        end
        if ~isempty(t_alr)
            b = discretize(t_alr, edges);
            alr_bin_mean = accumarray(b(~isnan(b)), z_alr(~isnan(b)), [nb 1], @median, NaN);
        end
    end
    abs_diff = abs(uvp_bin_mean - alr_bin_mean);  % NaN where either side missing

    % -------- Plotting (two stacked panels) ----------
    fig = figure('Visible','off');
    tl = tiledlayout(fig, 2, 1);
    tl.TileSpacing = 'compact'; tl.Padding = 'compact';

    % --- Top: time–depth (markers only, no joining) ---
    ax1 = nexttile(tl, 1); hold(ax1, 'on'); grid(ax1, 'on');
    addedUVPLegend = false;
    for s = 1:numel(uvp_time_series)
        if isempty(uvp_time_series{s}) || isempty(uvp_depth_series{s}), continue; end
        tt = uvp_time_series{s}; zz = uvp_depth_series{s};
        if isnumeric(tt), tt = datetime(tt,'ConvertFrom','datenum'); end
        if ~addedUVPLegend
            plot(ax1, tt, zz, '.', 'MarkerSize', 4, 'DisplayName', 'UVP');
            addedUVPLegend = true;
        else
            plot(ax1, tt, zz, '.', 'MarkerSize', 4, 'HandleVisibility','off');
        end
    end
    if haveALR
        plot(ax1, t_alr, z_alr, '.', 'MarkerSize', 8, 'DisplayName', 'ALR');
    end
    set(ax1, 'YDir','reverse');
    xlabel(ax1, 'Time'); ylabel(ax1, 'Depth (m)');
    if haveALR
        legend(ax1, 'Location','best');
    else
        legend(ax1, {'UVP'}, 'Location','best');
    end
    title(ax1, 'UVP & ALR time–depth');

    % --- Bottom: |deltadepth| per 10 s bin ---
    ax2 = nexttile(tl, 2); hold(ax2, 'on'); grid(ax2, 'on');
    if ~isempty(centers)
        plot(ax2, centers, (abs_diff./uvp_bin_mean)*100, '-', 'LineWidth', 1);
        ylabel(ax2, 'Depth Differnce (%)');
        yyaxis right
        plot(ax2, centers, abs_diff, '-', 'LineWidth', 1);
        ylabel(ax2, 'Depth Difference (m)');
    end
    xlabel(ax2, 'Time');
    title(ax2, ["Absolute and Relative percentage depth difference","((UVP - ALR) / Median UVP) * 100, 10 s median bins"]);

    linkaxes([ax1 ax2], 'x');

    % -------- Save and close ----------
    outpng = fullfile(outdir, 'uvp_alr_timedepth.png');
    print(fig, outpng, '-dpng', '-r150');
    close(fig);
    disp(['Saved diagnostic plot to: ' outpng])

catch ME
    disp(['Plotting skipped: ' ME.message])
end


%%

% -------------------------------------------------------------------------
% Addition: NORMALISE PER-ROW ARRAYS (place this just before "%% sample file writing")
% This ensures every array indexed in the writer loop has length N (the
% number of kept ALR samples), fixing "Index exceeds number of elements".
% -------------------------------------------------------------------------
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

% These are already per-ALR row; just ensure 1xN shape
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

% For ALR: segments that are not 'u' (up) or 'd' (down) are not vertical
% profiles and must use TIME integration, not DEPTH.
if strcmp(vector_type, 'ALR')
    for i = 1:N
        letter = char(profile_type_list(i));
        if ~strcmp(letter, 'u') && ~strcmp(letter, 'd')
            sample_type_list(i)      = "T";
            integration_time_list(i) = 1;
        else
            sample_type_list(i) = "P";
        end
    end
end

% UVP sequence struct array must be reindexed and shaped to 1xN
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

% Specific edits for alr project
cruise = 'DY180';
yo_list_2 = compose('segment_%d', yo_list);

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
                yo_list_2{seq_nb} ';'...
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
%% Additions not related to sample file output %%

%% Addition: combined diagnostic plot (UVP vs ALR time–depth + 10 s binned |Δdepth|)
try
    % ---------- Script directory (robust) ----------
    if ~isdeployed && usejava('desktop')
        thisfile = matlab.desktop.editor.getActiveFilename;
    else
        thisfile = mfilename('fullpath');
    end
    if isempty(thisfile), scriptDir = pwd; else, scriptDir = fileparts(thisfile); end

    outdir = fullfile(scriptDir, 'output');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    dailyDir = fullfile(outdir, 'daily_plots');
    if ~exist(dailyDir, 'dir'), mkdir(dailyDir); end
    overviewDir = fullfile(outdir, 'overview_plots');
    if ~exist(overviewDir, 'dir'), mkdir(overviewDir); end

    % -------- Gather & normalize time/depth to datetime ----------
    % UVP: concatenate all sequences
    t_uvp = []; z_uvp = [];
    for s = 1:numel(uvp_time_series)
        if isempty(uvp_time_series{s}) || isempty(uvp_depth_series{s}), continue; end
        t_uvp = [t_uvp; uvp_time_series{s}(:)];
        z_uvp = [z_uvp; uvp_depth_series{s}(:)];
    end
    if ~isempty(t_uvp)
        if isnumeric(t_uvp)
            t_uvp = datetime(t_uvp, 'ConvertFrom', 'datenum');
        elseif ~isdatetime(t_uvp)
            error('UVP time format not recognized.');
        end
    end

    % ALR
    t_alr = []; z_alr = [];
    haveALR = exist('alr_plot_time','var') && ~isempty(alr_plot_time);
    if haveALR
        t_alr = alr_plot_time(:);
        z_alr = alr_plot_depth(:);
        if isnumeric(t_alr)
            t_alr = datetime(t_alr, 'ConvertFrom', 'datenum');
        elseif ~isdatetime(t_alr)
            error('ALR time format not recognized.');
        end
    end

    % -------- Build 10-second bins over full data extent ----------
    if ~isempty(t_uvp) || ~isempty(t_alr)
        candidates_min = datetime.empty(0,1);
        candidates_max = datetime.empty(0,1);
        if ~isempty(t_uvp)
            candidates_min(end+1,1) = min(t_uvp);
            candidates_max(end+1,1) = max(t_uvp);
        end
        if ~isempty(t_alr)
            candidates_min(end+1,1) = min(t_alr);
            candidates_max(end+1,1) = max(t_alr);
        end
        t_min = min(candidates_min);
        t_max = max(candidates_max);

        edges   = (t_min:seconds(10):t_max+seconds(10)).';   % bin edges
        centers = edges(1:end-1) + seconds(5);               % bin centers
        nb = numel(edges)-1;
    else
        edges = datetime.empty; centers = datetime.empty; nb = 0;
    end

    % Median depth per 10 s bin for UVP and ALR (robust to outliers)
    uvp_bin_med = nan(nb,1);
    alr_bin_med = nan(nb,1);
    if nb > 0
        if ~isempty(t_uvp)
            b = discretize(t_uvp, edges);
            uvp_bin_med = accumarray(b(~isnan(b)), z_uvp(~isnan(b)), [nb 1], @median, NaN);
        end
        if ~isempty(t_alr)
            b = discretize(t_alr, edges);
            alr_bin_med = accumarray(b(~isnan(b)), z_alr(~isnan(b)), [nb 1], @median, NaN);
        end
    end
    abs_diff = abs(uvp_bin_med - alr_bin_med);              % NaN where either side missing
    rel_diff = 100 * (abs_diff ./ uvp_bin_med);             % (% of UVP)
    rel_diff(uvp_bin_med==0) = NaN;                         % avoid div-by-zero

    % --------- Master (full-span) 2-panel figure ----------
    fig = figure('Visible','off');
    tl = tiledlayout(fig, 2, 1, 'TileSpacing','compact','Padding','compact');

    ax1 = nexttile(tl, 1);
    ax2 = nexttile(tl, 2);

    if ~isempty(centers)
        fullStart = dateshift(min(centers),'start','day');
        fullEnd   = dateshift(max(centers),'start','day') + days(1);
    elseif ~isempty(t_uvp)
        fullStart = dateshift(min(t_uvp),'start','day');
        fullEnd   = dateshift(max(t_uvp),'start','day') + days(1);
    elseif ~isempty(t_alr)
        fullStart = dateshift(min(t_alr),'start','day');
        fullEnd   = dateshift(max(t_alr),'start','day') + days(1);
    else
        error('No time data to plot.');
    end

    plot_one_day(ax1, ax2, fullStart, fullEnd, ...
        uvp_time_series, uvp_depth_series, haveALR, t_alr, z_alr, ...
        centers, rel_diff, abs_diff);

    outpng = fullfile(outdir, 'uvp_alr_timedepth_fullspan.png');
    print(fig, outpng, '-dpng', '-r150');
    close(fig);
    disp(['Saved full-span diagnostic plot to: ' outpng]);

    % --------- Daily plots ----------
    if ~isempty(centers)
        dayStarts = unique(dateshift(centers(~isnat(centers)),'start','day'));
    else
        cands = [];
        if ~isempty(t_uvp), cands = [cands; t_uvp]; end
        if ~isempty(t_alr), cands = [cands; t_alr]; end
        dayStarts = unique(dateshift(cands,'start','day'));
    end

    for i = 1:numel(dayStarts)
        ds = dayStarts(i);
        de = ds + days(1);

        % Skip days with zero data
        hasUVP  = ~isempty(t_uvp) && any(t_uvp >= ds & t_uvp < de);
        hasALR  = haveALR        && any(t_alr >= ds & t_alr < de);
        hasBins = ~isempty(centers) && any(centers >= ds & centers < de & ( ~isnan(abs_diff) | ~isnan(rel_diff) ));
        if ~(hasUVP || hasALR || hasBins), continue; end

        fday = figure('Visible','off');
        tld = tiledlayout(fday, 2, 1, 'TileSpacing','compact','Padding','compact');
        axTop = nexttile(tld,1);
        axBot = nexttile(tld,2);

        plot_one_day(axTop, axBot, ds, de, ...
            uvp_time_series, uvp_depth_series, haveALR, t_alr, z_alr, ...
            centers, rel_diff, abs_diff);

        fname = sprintf('uvp_alr_timedepth_%s.png', datestr(ds,'yyyy-mm-dd'));
        print(fday, fullfile(dailyDir, fname), '-dpng', '-r150');
        close(fday);
        disp(['Saved daily plot to: ' fullfile(dailyDir, fname)]);
    end

    % --------- Overview multipanel (each day in its own tile) ----------
    ndays = numel(dayStarts);
    if ndays > 0
        cols = min(4, ndays);
        rows = ceil(ndays / cols);

        fov = figure('Visible','off');
        tlov = tiledlayout(fov, rows, cols, 'TileSpacing','compact','Padding','compact');

        for i = 1:ndays
            ds = dayStarts(i);
            de = ds + days(1);

            % Top (compact)
            axTop = nexttile(tlov);
            hold(axTop,'on'); grid(axTop,'on');
            for ss = 1:numel(uvp_time_series)
                if isempty(uvp_time_series{ss}) || isempty(uvp_depth_series{ss}), continue; end
                tt = uvp_time_series{ss}; zz = uvp_depth_series{ss};
                if isnumeric(tt), tt = datetime(tt,'ConvertFrom','datenum'); end
                sel = (tt >= ds) & (tt < de);
                if any(sel), plot(axTop, tt(sel), zz(sel), '.', 'MarkerSize', 2); end
            end
            if haveALR
                selA = (t_alr >= ds) & (t_alr < de);
                if any(selA), plot(axTop, t_alr(selA), z_alr(selA), '.', 'MarkerSize', 4); end
            end
            set(axTop,'YDir','reverse');
            title(axTop, datestr(ds,'yyyy-mm-dd'));
            xlabel(axTop,''); ylabel(axTop,'Depth (m)');

            % Bottom (compact) — enforce log % axis with fixed limits
            axBot = nexttile(tlov);
            hold(axBot,'on'); grid(axBot,'on');

            % Left axis (percentage, log)
            yyaxis(axBot,'left');
            rel_plot = rel_diff; rel_plot(rel_plot<=0) = NaN;     % sanitize for log
            axBot.YAxis(1).Scale  = 'log';
            axBot.YAxis(1).Limits = [0.1 1000];

            if ~isempty(centers)
                selB = (centers >= ds) & (centers < de);
                if any(selB)
                    plot(axBot, centers(selB), rel_plot(selB), '-', 'LineWidth', 0.75);
                end
            end
            ylabel(axBot,'Δdepth (%)');

            % Right axis (absolute, m)
            yyaxis(axBot,'right');
            if ~isempty(centers) && exist('selB','var') && any(selB)
                plot(axBot, centers(selB), abs_diff(selB), '-', 'LineWidth', 0.75);
            end
            ylabel(axBot,'Δdepth (m)');

            % Return to left
            yyaxis(axBot,'left');

            % Force datetime limits BEFORE linking
            xlim(axTop,[ds de]);
            xlim(axBot,[ds de]);
            linkaxes([axTop axBot],'x');

            xlabel(axBot,''); set(axBot,'XTickLabel',[]);
        end

        outOverview = fullfile(overviewDir, 'uvp_alr_timedepth_all_days.png');
        print(fov, outOverview, '-dpng', '-r200');
        close(fov);
        disp(['Saved overview multipanel to: ' outOverview]);
    end

catch ME
    disp(['Plotting skipped: ' ME.message])
end

%% Sampling interval diagnostics
fprintf('\n--- Sampling interval diagnostics ---\n');

% --- UVP ---
uvp_intervals = [];
for s = 1:numel(uvp_time_series)
    tt = uvp_time_series{s};
    if isempty(tt) || numel(tt) < 2, continue; end
    if isnumeric(tt)
        tt = datetime(tt,'ConvertFrom','datenum');
    elseif ~isdatetime(tt)
        warning('UVP sequence %d has unrecognized time format', s);
        continue;
    end
    dt = seconds(diff(tt));
    uvp_intervals = [uvp_intervals; dt(:)];
end

if isempty(uvp_intervals)
    warning('No valid UVP time intervals found.');
else
    fprintf('UVP median Δt = %.3f s (mean = %.3f s, N=%d)\n', ...
        median(uvp_intervals,'omitnan'), mean(uvp_intervals,'omitnan'), numel(uvp_intervals));
end

% --- ALR ---
alr_intervals = [];
if exist('alr_plot_time','var') && ~isempty(alr_plot_time)
    tt = alr_plot_time(:);
    if isnumeric(tt)
        tt = datetime(tt,'ConvertFrom','datenum');
    elseif ~isdatetime(tt)
        warning('ALR time format not recognized.');
        tt = [];
    end
    if numel(tt) > 1
        alr_intervals = seconds(diff(tt));
    end
end

if isempty(alr_intervals)
    warning('No valid ALR time intervals found.');
else
    fprintf('ALR median Δt = %.3f s (mean = %.3f s, N=%d)\n', ...
        median(alr_intervals,'omitnan'), mean(alr_intervals,'omitnan'), numel(alr_intervals));
end

% --- Optional: visualize distributions ---
figure('Visible','off'); hold on; grid on;
histogram(uvp_intervals, 'BinWidth', 1, 'DisplayName', 'UVP');
histogram(alr_intervals, 'BinWidth', 1, 'DisplayName', 'ALR');
xlabel('Interval between measurements (s)');
ylabel('Count');
legend show;
title('UVP vs ALR sampling interval distribution');
print(fullfile(outdir, 'uvp_alr_sampling_intervals.png'), '-dpng', '-r150');
close(gcf);

%% Addition: combined diagnostic plot (UVP vs ALR time–depth + 10 s binned |Δdepth|)
try
    % ---------- Script directory (robust) ----------
    if ~isdeployed && usejava('desktop')
        thisfile = matlab.desktop.editor.getActiveFilename;
    else
        thisfile = mfilename('fullpath');
    end
    if isempty(thisfile), scriptDir = pwd; else, scriptDir = fileparts(thisfile); end

    outdir = fullfile(scriptDir, 'output');
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    dailyDir = fullfile(outdir, 'daily_plots');
    if ~exist(dailyDir, 'dir'), mkdir(dailyDir); end
    overviewDir = fullfile(outdir, 'overview_plots');
    if ~exist(overviewDir, 'dir'), mkdir(overviewDir); end

    % -------- Gather & normalize time/depth to datetime ----------
    % UVP: concatenate all sequences
    t_uvp = []; z_uvp = [];
    for s = 1:numel(uvp_time_series)
        if isempty(uvp_time_series{s}) || isempty(uvp_depth_series{s}), continue; end
        t_uvp = [t_uvp; uvp_time_series{s}(:)];
        z_uvp = [z_uvp; uvp_depth_series{s}(:)];
    end
    if ~isempty(t_uvp)
        if isnumeric(t_uvp)
            t_uvp = datetime(t_uvp, 'ConvertFrom', 'datenum');
        elseif ~isdatetime(t_uvp)
            error('UVP time format not recognized.');
        end
    end

    % ALR
    t_alr = []; z_alr = [];
    haveALR = exist('alr_plot_time','var') && ~isempty(alr_plot_time);
    if haveALR
        t_alr = alr_plot_time(:);
        z_alr = alr_plot_depth(:);
        if isnumeric(t_alr)
            t_alr = datetime(t_alr, 'ConvertFrom', 'datenum');
        elseif ~isdatetime(t_alr)
            error('ALR time format not recognized.');
        end
    end

    % -------- Build 10-second bins over full data extent ----------
    if ~isempty(t_uvp) || ~isempty(t_alr)
        candidates_min = datetime.empty(0,1);
        candidates_max = datetime.empty(0,1);
        if ~isempty(t_uvp)
            candidates_min(end+1,1) = min(t_uvp);
            candidates_max(end+1,1) = max(t_uvp);
        end
        if ~isempty(t_alr)
            candidates_min(end+1,1) = min(t_alr);
            candidates_max(end+1,1) = max(t_alr);
        end
        t_min = min(candidates_min);
        t_max = max(candidates_max);

        edges   = (t_min:seconds(10):t_max+seconds(10)).';   % bin edges
        centers = edges(1:end-1) + seconds(5);               % bin centers
        nb = numel(edges)-1;
    else
        edges = datetime.empty; centers = datetime.empty; nb = 0;
    end

    % Median depth per 10 s bin for UVP and ALR (robust to outliers)
    uvp_bin_med = nan(nb,1);
    alr_bin_med = nan(nb,1);
    if nb > 0
        if ~isempty(t_uvp)
            b = discretize(t_uvp, edges);
            uvp_bin_med = accumarray(b(~isnan(b)), z_uvp(~isnan(b)), [nb 1], @median, NaN);
        end
        if ~isempty(t_alr)
            b = discretize(t_alr, edges);
            alr_bin_med = accumarray(b(~isnan(b)), z_alr(~isnan(b)), [nb 1], @median, NaN);
        end
    end
    abs_diff = abs(uvp_bin_med - alr_bin_med);              % NaN where either side missing
    rel_diff = 100 * (abs_diff ./ uvp_bin_med);             % (% of UVP)
    rel_diff(uvp_bin_med==0) = NaN;                         % avoid div-by-zero

    % --- Sliding 31-bin r^2 lag estimation (best offset vs time) ---
    lag_best_sec = []; lag_times = []; r2_best = [];
    if haveALR && ~isempty(centers)
        valid = isfinite(uvp_bin_med) & isfinite(alr_bin_med);
        if nnz(valid) >= 31
            u_use  = uvp_bin_med(valid);
            a_use  = alr_bin_med(valid);
            t_use  = centers(valid);

            % Bin duration (s)
            if numel(t_use) >= 2
                bin_dt = seconds(median(diff(t_use)));
                if ~isfinite(bin_dt) || bin_dt<=0, bin_dt = 10; end
            else
                bin_dt = 10;
            end

            N   = numel(u_use);
            W   = 31;               % 30-point (~31-bin) window
            hW  = floor(W/2);
            L   = max(1, round(60/bin_dt));  % ±60 s search

            nCenters     = N - 2*hW;
            lag_best_bins = NaN(nCenters,1);
            r2_best       = NaN(nCenters,1);
            lag_times     = t_use((1+hW):(N-hW));  % window centers

            for ci = 1:nCenters
                i0 = ci; i1 = ci + W - 1;
                uu = u_use(i0:i1); uu = uu - mean(uu,'omitnan');

                bestR2 = -Inf; bestLag = 0;
                for ell = -L:L
                    j0 = i0 + ell; j1 = i1 + ell;
                    if j0 < 1 || j1 > N, continue; end
                    aa = a_use(j0:j1); aa = aa - mean(aa,'omitnan');
                    if any(~isfinite(uu)) || any(~isfinite(aa)), continue; end

                    C = corrcoef(uu, aa);
                    if numel(C)==4 && all(isfinite(C(:)))
                        r2 = C(1,2)^2;
                        if r2 > bestR2
                            bestR2 = r2;
                            bestLag = ell;
                        end
                    end
                end
                lag_best_bins(ci) = bestLag;
                r2_best(ci)       = bestR2;
            end

            lag_best_sec = lag_best_bins * bin_dt;
        end
    end

    % --------- Master (full-span) 3-panel figure (adds Best Offset panel) ----------
    fig = figure('Visible','off');
    tl = tiledlayout(fig, 3, 1, 'TileSpacing','compact','Padding','compact');

    ax1 = nexttile(tl, 1);   % time–depth
    ax2 = nexttile(tl, 2);   % % and absolute Δdepth
    ax3 = nexttile(tl, 3);   % best offset (s), red crosses

    if ~isempty(centers)
        fullStart = dateshift(min(centers),'start','day');
        fullEnd   = dateshift(max(centers),'start','day') + days(1);
    elseif ~isempty(t_uvp)
        fullStart = dateshift(min(t_uvp),'start','day');
        fullEnd   = dateshift(max(t_uvp),'start','day') + days(1);
    elseif ~isempty(t_alr)
        fullStart = dateshift(min(t_alr),'start','day');
        fullEnd   = dateshift(max(t_alr),'start','day') + days(1);
    else
        error('No time data to plot.');
    end

    % Top two panels (your existing helper)
    plot_one_day(ax1, ax2, fullStart, fullEnd, ...
        uvp_time_series, uvp_depth_series, haveALR, t_alr, z_alr, ...
        centers, rel_diff, abs_diff);

    % Third panel: best offset (red crosses)
    hold(ax3,'on'); grid(ax3,'on');
    if ~isempty(lag_best_sec)
        plot(ax3, lag_times, lag_best_sec, 'x', 'MarkerSize', 6, 'LineWidth', 1.2, 'Color', [1 0 0]);
    end
    ylabel(ax3, 'Best offset (s) — 31-bin r^2');
    xlabel(ax3, 'Time');
    title(ax3, 'ALR → UVP offset (seconds)');

    % Force datetime limits on all panels, then link X
    xlim(ax1,[fullStart fullEnd]);
    xlim(ax2,[fullStart fullEnd]);
    xlim(ax3,[fullStart fullEnd]);
    linkaxes([ax1 ax2 ax3],'x');

    outpng = fullfile(outdir, 'uvp_alr_timedepth_fullspan.png');
    print(fig, outpng, '-dpng', '-r150');
    close(fig);
    disp(['Saved full-span diagnostic plot to: ' outpng]);

    % --------- Daily plots (unchanged) ----------
    if ~isempty(centers)
        dayStarts = unique(dateshift(centers(~isnat(centers)),'start','day'));
    else
        cands = [];
        if ~isempty(t_uvp), cands = [cands; t_uvp]; end
        if ~isempty(t_alr), cands = [cands; t_alr]; end
        dayStarts = unique(dateshift(cands,'start','day'));
    end

    for i = 1:numel(dayStarts)
        ds = dayStarts(i);
        de = ds + days(1);

        hasUVP  = ~isempty(t_uvp) && any(t_uvp >= ds & t_uvp < de);
        hasALR  = haveALR        && any(t_alr >= ds & t_alr < de);
        hasBins = ~isempty(centers) && any(centers >= ds & centers < de & ( ~isnan(abs_diff) | ~isnan(rel_diff) ));
        if ~(hasUVP || hasALR || hasBins), continue; end

        fday = figure('Visible','off');
        tld = tiledlayout(fday, 2, 1, 'TileSpacing','compact','Padding','compact');
        axTop = nexttile(tld,1);
        axBot = nexttile(tld,2);

        plot_one_day(axTop, axBot, ds, de, ...
            uvp_time_series, uvp_depth_series, haveALR, t_alr, z_alr, ...
            centers, rel_diff, abs_diff);

        fname = sprintf('uvp_alr_timedepth_%s.png', datestr(ds,'yyyy-mm-dd'));
        print(fday, fullfile(dailyDir, fname), '-dpng', '-r150');
        close(fday);
        disp(['Saved daily plot to: ' fullfile(dailyDir, fname)]);
    end

    % --------- Overview multipanel (unchanged) ----------
    ndays = numel(dayStarts);
    if ndays > 0
        cols = min(4, ndays);
        rows = ceil(ndays / cols);

        fov = figure('Visible','off');
        tlov = tiledlayout(fov, rows, cols, 'TileSpacing','compact','Padding','compact');

        for i = 1:ndays
            ds = dayStarts(i);
            de = ds + days(1);

            % Top (compact)
            axTop = nexttile(tlov);
            hold(axTop,'on'); grid(axTop,'on');
            for ss = 1:numel(uvp_time_series)
                if isempty(uvp_time_series{ss}) || isempty(uvp_depth_series{ss}), continue; end
                tt = uvp_time_series{ss}; zz = uvp_depth_series{ss};
                if isnumeric(tt), tt = datetime(tt,'ConvertFrom','datenum'); end
                sel = (tt >= ds) & (tt < de);
                if any(sel), plot(axTop, tt(sel), zz(sel), '.', 'MarkerSize', 2); end
            end
            if haveALR
                selA = (t_alr >= ds) & (t_alr < de);
                if any(selA), plot(axTop, t_alr(selA), z_alr(selA), '.', 'MarkerSize', 4); end
            end
            set(axTop,'YDir','reverse');
            title(axTop, datestr(ds,'yyyy-mm-dd'));
            xlabel(axTop,''); ylabel(axTop,'Depth (m)');

            % Bottom (compact) — enforce log % axis with fixed limits
            axBot = nexttile(tlov);
            hold(axBot,'on'); grid(axBot,'on');
            yyaxis(axBot,'left');
            rel_plot = rel_diff; rel_plot(rel_plot<=0) = NaN;
            axBot.YAxis(1).Scale  = 'log';
            axBot.YAxis(1).Limits = [0.1 1000];

            if ~isempty(centers)
                selB = (centers >= ds) & (centers < de);
                if any(selB)
                    plot(axBot, centers(selB), rel_plot(selB), '-', 'LineWidth', 0.75);
                end
            end
            ylabel(axBot,'Δdepth (%)');

            yyaxis(axBot,'right');
            if ~isempty(centers) && exist('selB','var') && any(selB)
                plot(axBot, centers(selB), abs_diff(selB), '-', 'LineWidth', 0.75);
            end
            ylabel(axBot,'Δdepth (m)');

            yyaxis(axBot,'left');
            xlim(axTop,[ds de]); xlim(axBot,[ds de]); linkaxes([axTop axBot],'x');
            xlabel(axBot,''); set(axBot,'XTickLabel',[]);
        end

        outOverview = fullfile(overviewDir, 'uvp_alr_timedepth_all_days.png');
        print(fov, outOverview, '-dpng', '-r200');
        close(fov);
        disp(['Saved overview multipanel to: ' outOverview]);
    end

catch ME
    disp(['Plotting skipped: ' ME.message])
end


%%

xx_alr_time_remap = alr_plot_time;
xx_alr_depth_remap = alr_plot_depth;

xx_uvp_time_remap = uvp_time_series{:};
xx_uvp_depth_remap = uvp_depth_series{:};

%% -------- Helper: plot one day into given axes ----------
function plot_one_day(axTop, axBot, dayStart, dayEnd, ...
    uvp_time_series, uvp_depth_series, haveALR, t_alr, z_alr, ...
    centers, rel_diff, abs_diff)

    % Top panel: raw markers (no joining)
    hold(axTop,'on'); grid(axTop,'on');
    addedUVPLegend = false;
    for ss = 1:numel(uvp_time_series)
        if isempty(uvp_time_series{ss}) || isempty(uvp_depth_series{ss}), continue; end
        tt = uvp_time_series{ss}; zz = uvp_depth_series{ss};
        if isnumeric(tt), tt = datetime(tt,'ConvertFrom','datenum'); end
        sel = (tt >= dayStart) & (tt < dayEnd);
        if any(sel)
            if ~addedUVPLegend
                plot(axTop, tt(sel), zz(sel), '.', 'MarkerSize', 4, 'DisplayName','UVP');
                addedUVPLegend = true;
            else
                plot(axTop, tt(sel), zz(sel), '.', 'MarkerSize', 4, 'HandleVisibility','off');
            end
        end
    end
    if haveALR
        selA = (t_alr >= dayStart) & (t_alr < dayEnd);
        if any(selA)
            plot(axTop, t_alr(selA), z_alr(selA), '.', 'MarkerSize', 8, 'DisplayName','ALR');
        end
    end
    set(axTop, 'YDir','reverse');
    xlabel(axTop, 'Time'); ylabel(axTop, 'Depth (m)');
    if haveALR, legend(axTop, 'Location','best'); else, legend(axTop, {'UVP'}, 'Location','best'); end
    title(axTop, sprintf('UVP & ALR time–depth (%s)', datestr(dayStart,'yyyy-mm-dd')));

    % Bottom panel: relative (%) and absolute (m) differences for that day
    hold(axBot,'on'); grid(axBot,'on');

    % Left axis (percentage) — log with fixed limits
    yyaxis(axBot,'left');
    rel_plot = rel_diff; rel_plot(rel_plot<=0) = NaN;   % sanitize
    axBot.YAxis(1).Scale  = 'log';
    axBot.YAxis(1).Limits = [0.1 1000];

    if ~isempty(centers)
        selB = (centers >= dayStart) & (centers < dayEnd);
        if any(selB)
            plot(axBot, centers(selB), rel_plot(selB), '-', 'LineWidth', 1);
        end
    end
    ylabel(axBot, 'Depth Difference (%)');

    % Right axis (absolute m)
    yyaxis(axBot,'right');
    if ~isempty(centers) && exist('selB','var') && any(selB)
        plot(axBot, centers(selB), abs_diff(selB), '-', 'LineWidth', 1);
    end
    ylabel(axBot, 'Depth Difference (m)');

    % Return to left for consistency
    yyaxis(axBot,'left');

    % Force datetime limits BEFORE linking (avoids mixed-type linkaxes error)
    xlim(axTop, [dayStart dayEnd]);
    xlim(axBot, [dayStart dayEnd]);

    linkaxes([axTop axBot],'x');
end