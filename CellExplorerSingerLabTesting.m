%% Cell Explorer - Update Task Pipeline

%% Set parameters

% set animal inputs to run
animals = [17, 20, 25, 28, 29];
daysincl = [];
datesexcl = [nan];
overwrite_cell_metrics = true;  % reruns process cell metrics function
force_reload = true;  % reruns all cell metrics calculations
polarity_threshold = 0.25;
new_unit_ids = true; 

% set basepaths and
%base_folder = 'Y:\singer\Steph\Code\singer-lab-to-nwb\data\ProcessedData\UpdateTask\';
base_folder = 'Y:\singer\ProcessedData\UpdateTask\';
spreadsheetdir = 'Y:\singer\Steph\Code\update-project\docs\metadata-summaries\VRUpdateTaskEphysSummary.csv';
if new_unit_ids
    kilosort_path = 'new_unit_ids';
else
    kilosort_path = '';
end
basepaths_all = [];
basenames_all = [];

%get the animal info based on the inputs
allindexT = selectindextable(spreadsheetdir, 'animal', animals, 'datesincluded', daysincl, 'datesexcluded', datesexcl);
allindex = allindexT{:,{'Animal', 'Date','Recording'}};
[sessions, ind] = unique(allindex(:,1:2), 'rows'); %define session as one date

%% Run Cell Explorer Pipeline
for d = 1:size(sessions,1)
    %% get the session info
    sessionInfo = allindex(ismember(allindex(:,1:2), sessions(d,:), 'rows'),:);
    files = sessionInfo(:,3);
    animal = sessionInfo(1,1);
    day =  sessionInfo(1,2);
    brain_regions = allindexT{allindexT.Animal == animal & allindexT.Date == day & allindexT.Recording == files(1),{'RegAB','RegCD'}};
    session_id = ['S' num2str(animal) '_' num2str(day)];
    
    %% generate the metadata and input structures
    for br = 1:numel(brain_regions)
        % Check if single unit data exists for that day and run if it does
        data_path = fullfile(base_folder, session_id, brain_regions{br}, 'sorted', 'kilosort');
        if isfolder(data_path)
            % save basepaths and basenames for compiling
            basepaths{br} = data_path;
            basenames{br} = [session_id '_' brain_regions{br}];
            
            if overwrite_cell_metrics
                % create session metadata structure and validate
                session = UpdateTaskTemplate(basepaths{br}, 'basename', basenames{br}, ... 
                'overwrite', false, 'brainRegion', brain_regions{br}, 'electrodeGroup', br,...
                'kilosortFolder', kilosort_path);
                validateSessionStruct(session);

                %% Run the cell metrics pipeline 'ProcessCellMetrics' using the session struct as input
                exclude_metrics = {'monoSynaptic_connections','spatial_metrics','event_metrics','manipulation_metrics'};
                ProcessCellMetrics('session', session, 'excludeMetrics', exclude_metrics,'forceReload', force_reload, 'keepCellClassification', ~force_reload,...
                'polarityThreshold', polarity_threshold); 
            end
        else
            disp(['Spike sorted data missing for ' session_id '_' brain_regions{br}])
        end
    end
    
    if overwrite_cell_metrics
        %% Save sessions for both brain regions
        % load batch session
        cell_metrics = loadCellMetricsBatch('basepaths', basepaths, 'basenames', basenames);

        % save data to main file
        out_filename = fullfile(base_folder, session_id, 'cellTypeClassification.mat');
        saveCellMetrics(cell_metrics, out_filename);
        close all;
    end
    
    %% compile data
    basepaths_all = [basepaths_all, basepaths];
    basenames_all = [basenames_all, basenames];
end

%% Open sessions for ALL files 
cell_metrics = loadCellMetricsBatch('basepaths', basepaths_all, 'basenames', basenames_all);
cell_metrics = CellExplorer('metrics',cell_metrics); %uncomment this if you want to use the gui to visualize