function [meta_data_folder, vector_sn] = DetectionVectorMetaFile(project_folder, vector_type)
%DetectionVectorMetaFile detect if there is a meta data file from the
%vector in the project
%
%
% inputs :
%   project_folder : full path of the project
%   vector_type : 'SeaExplorer' or 'SeaGlider' or 'float'
%
% output :
%   meta_data_folder : full path of metadata vector folder
%   vector_sn : vector name and sn
%
if strcmp(vector_type, 'SeaExplorer')
    list_in_doc = dir(fullfile(project_folder, 'doc', 'SEA*'));
    if isempty(list_in_doc)
        error('ERROR : No metadata folder found in \doc')
    end
    vector_sn = ['Seaeplorer_' list_in_doc(1).name(4:6)];
elseif strcmp(vector_type, 'SeaGlider')
    list_in_doc = dir(fullfile(project_folder, 'doc', 'SG*'));
    if isempty(list_in_doc)
        error('ERROR : No metadata folder found in \doc')
    end
    vector_sn = ['SeaGlider_' list_in_doc(1).name(3:5)];
elseif strcmp(vector_type, 'float')
    list_in_doc = dir(fullfile(project_folder, 'doc', 'float*'));
    if isempty(list_in_doc)
        error('ERROR : No metadata folder found in \doc')
    end
    vector_sn = ['WMO' list_in_doc(1).name(end-6:end)];
elseif strcmp(vector_type, 'ALR')
    list_in_doc = dir(fullfile(project_folder, 'doc', 'alr_meta_sn*'));
    if isempty(list_in_doc)
        error('ERROR : No ALR metadata folder found in \doc (expected "alr_meta_sn*")')
    end
    fname = list_in_doc(1).name; % alr_meta_sn004
    sn = regexp(fname, 'sn(\d+)', 'tokens', 'once');
    if ~isempty(sn)
        vector_sn = ['ALR' sprintf('%03d', str2double(sn{1}))];
    else
        nc_list = dir(fullfile(list_in_doc(1).folder, list_in_doc(1).name, '*.nc'));
        if isempty(nc_list)
            error('ERROR: ALR meta folder contains no .nc files');
        end
        try
            alr_serial = ncreadatt(fullfile(nc_list(1).folder, nc_list(1).name), '/', 'alr_serial');
            vector_sn = regexprep(alr_serial, '[^\w]', '');
        catch
            warning('Could not read alr_serial; using "ALR".');
            vector_sn = 'ALR';
        end
    end
end

meta_data_folder = fullfile(list_in_doc(1).folder, list_in_doc(1).name);
% if it is not a dir, try to unzip it
if ~list_in_doc(1).isdir
    gunzip(meta_data_folder, list_in_doc(1).folder);
    meta_data_folder = fullfile(list_in_doc(1).folder, list_in_doc(1).name(1:end-4));
end

disp(['Vector meta data folder : ', list_in_doc(1).name])

end