%% Cell Explorer - Update Task Pipeline

%% Set parameters

% set animal inputs to run
animals = [25];
daysincl = [210913];
datesexcl = [nan];

base_folder = 'Y:\singer\Steph\Code\singer-lab-to-nwb\data\ProcessedData\UpdateTask\';

%get the animal info based on the inputs
allindexT = selectindextable(dirs.spreadsheetdir, 'animal', animals, 'datesincluded', daysincl, 'datesexcluded', datesexcl);
allindex = allindexT{:,{'Animal', 'Date','Recording'}};
[sessions, ind] = unique(allindex(:,1:2), 'rows'); %define session as one date

%% Run Cell Explorer Pipeline
for d = 1:size(sessions,1)
    %% get the session info
    files = sessionInfo(:,3);
    animal = sessionInfo(1,1);
    day =  sessionInfo(1,2);
    brain_regions = allindexT{allindexT.Animal == animal & allindexT.Date == day & allindexT.Recording == files(1),{'RegAB','RegCD'}};
    session_id = ['S' num2str(animal) '_' num2str(day)];

    %% generate the metadata and input structures
    for br = 1:numel(brain_regions)
        % Check if single unit data exists for that day and run if it does
        sorted_path = fullfile(base_folder, session_id, brain_regions{br}, 'sorted', 'kilosort');
        if isfolder(sorted_path)
            % save basepaths and basenames for compiling
            basepaths{br} = sorted_path;
            basenames{br} = [session_id '_' brain_regions{br}];
            
            % create session metadata structure and validate
            session = UpdateTaskTemplate(basepaths{br}, 'basename', basenames{br}, ... 
            'overwrite', false, 'brainRegion', brain_regions{br}, 'electrodeGroup', br);
            validateSessionStruct(session);

            %% Run the cell metrics pipeline 'ProcessCellMetrics' using the session struct as input
            exclude_metrics = {'monoSynaptic_connections','spatial_metrics','event_metrics','manipulation_metrics'};
            ProcessCellMetrics('session', session, 'excludeMetrics', exclude_metrics);
        end
    end

    %% Open sessions for both brain regions
    % load batch session
    out_filename = fullfile(base_folder, session_id, 'cellTypeClassification.mat');
    cell_metrics = loadCellMetricsBatch('basepaths', basepaths, 'basenames', basenames);
    %cell_metrics = CellExplorer('metrics',cell_metrics); %uncomment this if you want to use the gui to visualize
    
    % save data to main file
    saveCellMetrics(cell_metrics, out_filename);
    close all;
end