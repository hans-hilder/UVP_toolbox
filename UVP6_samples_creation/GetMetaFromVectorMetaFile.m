function [lon_list, lat_list, yo_list, samples_names_list, vector_filenames_list, ...
          start_idx_list, end_idx_list, start_time_list, assigned_uvp_seq_idx, ...
          alr_plot_time, alr_plot_depth, skipped_count, total_alr] = ...
    GetMetaFromVectorMetaFile(vector_type, meta_data_folder, ref_time_list, ...
                              list_of_sequences, profile_type_list, cruise, ...
                              uvp_time_series, uvp_depth_series, start_idx_list, end_idx_list)

%GetMetaFromVectorMetaFile get latitude, longitude and yo number
%corresponding to the sequences
%
%
% inputs :
%   vector_type : 'SeaExplorer' or 'SeaGlider' or 'float'
%   meta_data_folder : full path to vector meta folder
%   ref_time_list : list of sequences reference time (start or end)
%   list_of_sequences : dir of sequences folder
%   profile_type_list : 'd' or 'a', descent or ascent, array of string on
%   samples length ('p' for parking)
%   cruise : cruise name (str)
%
% output :
%   lon_list : vector of longitude
%   lat_list : vector of latitude
%   yo_list : list of yo nb
%   samples_names_list : list of samples names
%   vector_filenames_list : list of name of vector nc file
%

% get list of meta files
if strcmp(vector_type, 'SeaExplorer')
    % raw.gz for seaexplorer
    list_of_vector_meta = dir(fullfile(meta_data_folder, 'ccu', 'logs', '*raw*'));
    % reorder the list of file to have ...8,9,10,11... and not ...1,100,101,...
    [~, idx] = sort( str2double( regexp( {list_of_vector_meta.name}, '\d+(?=\.gz)', 'match', 'once' )));
    list_of_vector_meta = list_of_vector_meta(idx);
    meta_folder_ccu = list_of_vector_meta(1).folder;

elseif strcmp(vector_type, 'SeaGlider')
    % nc for seaglider
    list_of_vector_meta = dir(fullfile(meta_data_folder, '*.nc'));
    meta_folder_sg = list_of_vector_meta(1).folder;

elseif strcmp(vector_type, 'float')
    % nc for float
    list_of_vector_meta = dir(fullfile(meta_data_folder, 'S*.nc'));
    meta_folder_fl = list_of_vector_meta(1).folder;

elseif strcmp(vector_type, 'ALR')
    list_of_vector_meta = dir(fullfile(meta_data_folder, '*.nc'));
    if isempty(list_of_vector_meta)
        error('No ALR .nc files found in %s', meta_data_folder);
    end
    meta_folder_alr = list_of_vector_meta(1).folder;
end

seq_nb_max = length(list_of_sequences);
lon_list = zeros(1, seq_nb_max);
lat_list = zeros(1, seq_nb_max);
yo_list = zeros(1, seq_nb_max);
samples_names_list = strings(1, seq_nb_max);
vector_filenames_list = strings(1, seq_nb_max);
% sequence number with found meta data
seq_nb = 1;
yo_nb = 0;

% find lat-lon directly with time first image
% assume lat-lon is interpolated by the glider
for meta_nb = 1:length(list_of_vector_meta)
    % read metadata from file
    if strcmp(vector_type, 'SeaExplorer')
        [meta, data] = ReadDataSeaexplorer(fullfile(meta_folder_ccu, list_of_vector_meta(meta_nb).name));

    elseif strcmp(vector_type, 'SeaGlider')
        [meta, data] = ReadMetaSeaglider(fullfile(meta_folder_sg, list_of_vector_meta(meta_nb).name));

    elseif strcmp(vector_type, 'float')
        [meta, data] = ReadMetaFloat(fullfile(meta_folder_fl, list_of_vector_meta(meta_nb).name));

    elseif strcmp(vector_type, 'ALR')
        [meta, data] = ReadMetaALR(fullfile(meta_folder_alr, list_of_vector_meta(meta_nb).name));
    end
    right_meta = 1;
    % while it is a useful meta data file compared to the datetime of the
    % sequence
    while right_meta == 1 && seq_nb <= seq_nb_max
        if strcmp(profile_type_list(seq_nb), 'p')
            % look for the seq nb of the ascent profile
            ind_ascent = find(profile_type_list == 'a');
            ind_ascent_next = ind_ascent(ind_ascent > seq_nb);
            ref_seq_nb = ind_ascent_next(1);
        else
            ref_seq_nb = seq_nb;
        end
        time_to_find = ref_time_list(ref_seq_nb);
        samples_names_list(seq_nb) = num2str(seq_nb);

        % check that the datetime of the sequence IS in the file
        % of the datetime+10s (in case of non synchro)
        % if not, go to the next meta data file

        if strcmp(vector_type,'ALR') || ((time_to_find + datenum(duration('00:00:10')) >= meta(1,1)) && (time_to_find <= meta(end,1))) || (...
                ((time_to_find + datenum(duration('00:50:00')) >= meta(1,1)) && strcmp(vector_type, 'float')) && ...
                ((time_to_find  - datenum(duration('00:30:00')) <= meta(end,1)) && strcmp(vector_type, 'float')))
           aa =  find(meta(:,1) <= time_to_find);
           
           if isempty(aa) && strcmp(vector_type, 'float')
               aa =  find(meta(:,1) <= (time_to_find + datenum(duration('00:50:00'))));
           elseif isempty(aa)
               aa =  find(meta(:,1) <= (time_to_find + datenum(duration('00:00:10'))));
           end
           disp(['Vector meta data for ' list_of_sequences(seq_nb).name ' found'])

           if strcmp(vector_type, 'SeaExplorer')
               lat_list(seq_nb) = ConvertLatLonSeaexplorer(meta(aa(end), 3));
               lon_list(seq_nb) = ConvertLatLonSeaexplorer(meta(aa(end), 4));
               yo_nb = strsplit(list_of_vector_meta(meta_nb).name, '.');
               yo_nb = yo_nb(end-1);
               yo_list(seq_nb) = str2double(yo_nb);
               samples_names_list(seq_nb) = ['Yo_' num2str(yo_list(seq_nb), '%04.f') char(profile_type_list(seq_nb)) '_' cruise];

           elseif strcmp(vector_type, 'SeaGlider')
               lat_list(seq_nb) = meta(aa(end), 3);
               lon_list(seq_nb) = meta(aa(end), 4);
               %if (seq_nb>1) && strcmp(profile_type_list(seq_nb), 'd') && strcmp(profile_type_list(seq_nb-1), 'a')
               % Was to avoid problem before merge sequences -> depreciated
               if not( (seq_nb>1) && strcmp(profile_type_list(seq_nb), 'a') && strcmp(profile_type_list(seq_nb-1), 'd') )
                   yo_nb = yo_nb + 1;
               end
               yo_list(seq_nb) = yo_nb;
               if (seq_nb>1) && strcmp(samples_names_list(seq_nb-1), ['Yo_' num2str(yo_list(seq_nb)) char(profile_type_list(seq_nb)) '_' cruise])
                   samples_names_list(seq_nb) = ['Yo_' num2str(yo_list(seq_nb), '%04.f') char(profile_type_list(seq_nb)) '2_' cruise];
               else
                   samples_names_list(seq_nb) = ['Yo_' num2str(yo_list(seq_nb), '%04.f') char(profile_type_list(seq_nb)) '_' cruise];
               end

           elseif strcmp(vector_type, 'float')
               %if yo_nb == 0
               %    yo_nb = 1;
               %end
               lat_list(seq_nb) = meta(aa(end), 3);
               lon_list(seq_nb) = meta(aa(end), 4);
               yo_list(seq_nb) = yo_nb;
               if strcmp(profile_type_list(seq_nb), 'a')
                   yo_nb = yo_nb + 1;
               end
               samples_names_list(seq_nb) = [num2str(yo_list(seq_nb), '%04.f') char(profile_type_list(seq_nb)) '_' cruise];

            elseif strcmp(vector_type, 'ALR')
                list_of_vector_meta = dir(fullfile(meta_data_folder, '*.nc'));
                if isempty(list_of_vector_meta)
                    error('No ALR .nc files found in %s', meta_data_folder);
                end
                meta_folder_alr = list_of_vector_meta(1).folder;
            
                % --- Accumulators (per-ALR sample) ---
                lat_acc   = [];
                lon_acc   = [];
                yo_acc    = [];
                name_acc  = strings(0,1);
                vfn_acc   = strings(0,1);
                sidx_acc  = [];
                eidx_acc  = [];
                stime_acc = [];
                uvp_seq_acc = [];
            
                % Plotting accumulators
                alr_plot_time  = [];
                alr_plot_depth = [];
            
                skipped_count = 0;
                total_alr     = numel(list_of_vector_meta);
                tol = datenum(seconds(10));  % ±10 s
            
                % Walk every ALR file and pick the UVP sequence with the largest overlap
                for k = 1:total_alr
                    nc_path = fullfile(meta_folder_alr, list_of_vector_meta(k).name);
                    [meta, data] = ReadMetaALR(nc_path);
                    t_alr = meta(:,1);
                    if isempty(t_alr) || all(isnan(t_alr))
                        skipped_count = skipped_count + 1;
                        continue
                    end
            
                    % Best overlap against all UVP sequences
                    tmin = min(t_alr) - tol;
                    tmax = max(t_alr) + tol;
                    best_count = 0;
                    best_seq   = NaN;
                    best_idx   = [];
            
                    for s = 1:numel(uvp_time_series)
                        if isempty(uvp_time_series{s}), continue; end
                        t_uvp = uvp_time_series{s};
                        idx = find( (t_uvp >= tmin) & (t_uvp <= tmax) );
                        c = numel(idx);
                        if c > best_count
                            best_count = c; best_seq = s; best_idx = idx;
                        end
                    end
            
                    if best_count == 0 || isnan(best_seq)
                        skipped_count = skipped_count + 1;
                        continue
                    end
            
                    % Build indices (0-based for UVP app)
                    sidx  = best_idx(1)  - 1;
                    eidx  = best_idx(end) - 1;
                    stime = uvp_time_series{best_seq}(best_idx(1));
            
                    % Lat/Lon as median over file, or as first value in
                    % file
                    lat_vals = meta(:,3); lon_vals = meta(:,4);
                    %lat_keep = median(lat_vals(~isnan(lat_vals)));
                    lat_keep = lat_vals(1);
                    %lon_keep = median(lon_vals(~isnan(lon_vals)));
                    lon_keep = lon_vals(1);
            
                    % Names/IDs from ALR filename
                    fname = list_of_vector_meta(k).name;
                    [~, base, ~] = fileparts(fname);
                    nums = regexp(base, '\d+', 'match');  % ALR###_YYYYMMDD_uuuu_ssss_L#### -> 4th = segment_ID
                    seg_id = NaN; if numel(nums) >= 4, seg_id = str2double(nums{4}); end
            
                    % Accumulate
                    name_acc(end+1,1) = string(base);
                    vfn_acc(end+1,1)  = string(fname);
                    yo_acc(end+1,1)   = seg_id;
                    lat_acc(end+1,1)  = lat_keep;
                    lon_acc(end+1,1)  = lon_keep;
                    sidx_acc(end+1,1) = sidx;
                    eidx_acc(end+1,1) = eidx;
                    stime_acc(end+1,1)= stime;
                    uvp_seq_acc(end+1,1) = best_seq;
            
                    % One CSV per ALR file (matches prior behavior but with ALR basename)
                    try
                        CreateCTDfile(fullfile(meta_data_folder, '..', '..'), data, strcat(base, '.csv'), vector_type); % Addition
                    catch
                        % non-fatal; continue
                    end
            
                    % For plotting
                    if ismember('DEPTH_SCI', data.Properties.VariableNames)
                        alr_plot_time  = [alr_plot_time;  t_alr(:)];
                        alr_plot_depth = [alr_plot_depth; data.DEPTH_SCI(:)];
                    end
                end
            
                % --- Enforce non-overlapping image indices per UVP sequence ---
                if ~isempty(sidx_acc)
                    row_ids = (1:numel(sidx_acc)).';
                    order = sortrows([row_ids, uvp_seq_acc(:), sidx_acc(:)], [2 3]);
                    order_ids  = order(:,1);
                    order_seqs = order(:,2);
            
                    prev_idx_per_seq = NaN(1, max(numel(uvp_time_series), max(uvp_seq_acc)));
                    for k = 1:numel(order_ids)
                        j   = order_ids(k);
                        seq = order_seqs(k);
                        s_j = sidx_acc(j);
                        prev = prev_idx_per_seq(seq);
                        if ~isnan(prev)
                            e_prev_new = min(eidx_acc(prev), s_j - 1);
                            e_prev_new = max(e_prev_new, sidx_acc(prev));   % ensure end >= start
                            eidx_acc(prev) = e_prev_new;
                        end
                        prev_idx_per_seq(seq) = j;
                    end
                end
            
                % --- Convert accumulators to outputs and RETURN ---
                lat_list = lat_acc(:).';
                lon_list = lon_acc(:).';
                yo_list  = yo_acc(:).';
                samples_names_list    = name_acc(:).';
                vector_filenames_list = vfn_acc(:).';
                start_idx_list   = sidx_acc(:).';
                end_idx_list     = eidx_acc(:).';
                start_time_list  = stime_acc(:).';
                assigned_uvp_seq_idx = uvp_seq_acc(:).';
            
                if isempty(samples_names_list)
                    warning('No ALR samples matched any UVP times within ±10 s.');
                end
            
                return;  % <<< prevents falling through to the legacy seq_nb logic

           end
          [~] = CreateCTDfile(fullfile(meta_data_folder, '..', '..'), data, strcat(samples_names_list(seq_nb), '.csv'), vector_type);
           vector_filenames_list(seq_nb) = list_of_vector_meta(meta_nb).name;
           seq_nb = seq_nb + 1;

        elseif (time_to_find < meta(1,1))
            seq_nb = seq_nb + 1;
        else
            right_meta = 0;
        end
    end
    if seq_nb > seq_nb_max
        break
    end
end



end