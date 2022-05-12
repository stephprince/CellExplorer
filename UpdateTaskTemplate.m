function session = UpdateTaskTemplate(input1,varargin)
% This script can be used to create a session struct (the metadata structure used by CellExplorer).
% It must be called from the basepath of your dataset, or be provided with a basepath as input (first input)
% Check the website of the CellExplorer for more details: https://cellexplorer.org/
%
% It will detect and load metadata files and fill out default metadata, including:
%    - Neurosuite xml file
%    - Buzcode sessionInfo file
%    - Intan's metadata file info.rhd
%    - Determine spike data format from existance of files and folders in the basepath (if any exist: Phy,
%         Klustakwik, Klustaviewa, UltraMegaSort2000, MClust)
%    - Detect Kilosort output folder
%    - Set default animal metadata (name, species, strain)
%    - Set default extracellular metadata
%    - Other parameters specified in this script.
% 
% You can create your own custom template, simply by generating a new templatescript from this file and change the defaults accordingly 
% E.g. : session = sessionTemplateCustom(input1,varargin)
%
% - Example calls:
% session = sessionTemplate(session)                                % Load session from session struct
% session = sessionTemplate(basepath,'showGUI',true)                % Load from basepath and shows gui
% session = sessionTemplate(basepath,'basename','name_of_session')

% By Peter Petersen
% petersen.peter@gmail.com
% Last edited: 30-07-2021

p = inputParser;
addRequired(p,'input1',@(X) (ischar(X) && exist(X,'dir')) || isstruct(X)); % specify a valid path or an existing session struct
addParameter(p,'basename',[],@isstr);
addParameter(p,'kilosortFolder',[],@isstr);
addParameter(p,'importSkippedChannels',true,@islogical); % Import skipped channels from the xml as bad channels
addParameter(p,'importSyncedChannels',true,@islogical);  % Import channel not synchronized between electrode groups and spike groups as bad channels
addParameter(p,'showGUI',false,@islogical);              % Show the session gui
addParameter(p,'brainRegion',[],@isstr); % Import brain region information
addParameter(p,'electrodeGroup',[],@isnumeric); % Import electrode group based on brain region
addParameter(p,'overwrite',false,@islogical); % Default to load existing session files

% Parsing inputs
parse(p,input1,varargin{:})
basename = p.Results.basename;
importSkippedChannels = p.Results.importSkippedChannels;
importSyncedChannels = p.Results.importSyncedChannels;
showGUI = p.Results.showGUI;
brainRegion = p.Results.brainRegion;
electrodeGroup = p.Results.electrodeGroup;
overwrite = p.Results.overwrite;
kiloSortFolder = p.Results.kilosortFolder;

% Initializing session struct and defining basepath, if not specified as an input
if ischar(input1)
    basepath = input1;
    cd(basepath)
elseif isstruct(input1)
    session = input1;
    if isfield(session.general,'basePath') && exist(session.general.basePath,'dir')
        basepath = session.general.basePath;
        cd(basepath)
    else
        basepath = pwd;
    end
end

% Loading existing basename.session.mat file if exist
if isempty(basename)
    basename = basenameFromBasepath(basepath);
end
if ~exist('session','var') && exist(fullfile(basepath,[basename,'.session.mat']),'file') && ~overwrite
    disp('Loading existing basename.session.mat file')
    session = loadSession(basepath,basename);
elseif ~exist('session','var')
    session = [];
end

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Standard parameters below. Please change accordingly to represent your session
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
pathPieces = regexp(basepath, filesep, 'split'); % Assumes file structure: animal/session/

% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% General metadata
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% From the provided path, the session name, clustering path will be implied
session.general.basePath =  basepath; % Full path
session.general.name = basename; % Session name / basename
session.general.version = 5; % Metadata version
session.general.sessionType = 'Acute'; % Type of recording: Chronic, Acute, Unknown

% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Limited animal metadata (practical information)
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% The animal data is relevant for filtering across datasets in CellExplorer
if ~isfield(session,'animal')
    session.animal.name = pathPieces{end-1}; % Animal name is inferred from the data path
    session.animal.sex = 'Male'; % Male, Female, Unknown
    session.animal.species = 'Mouse'; % Mouse, Rat
    session.animal.strain = 'C57Bl/6J';
    session.animal.geneticLine = '';
end

% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Extracellular
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
%This section will set some default extracellular parameters. You can comment this out if you are importing these parameters another way. 
%Extracellular parameters from a Neuroscope xml and buzcode sessionInfo file will be imported as well
if ~isfield(session,'extracellular') || (isfield(session,'extracellular') && (~isfield(session.extracellular,'sr')) || isempty(session.extracellular.sr))
    %session.extracellular.sr = 30000;           % Sampling rate of raw data
    %session.extracellular.srLfp = 2000;         % Sampling rate of LFP data
    %session.extracellular.nChannels = 128;       % number of channels
    session.extracellular.fileName = 'allrecordings.bin';        % (optional) file name of raw data if different from basename.dat
    %session.extracellular.electrodeGroups.channels = {[1:session.extracellular.nChannels]}; %creating a default list of channels. Please change according to your own layout. 
    %session.extracellular.nElectrodeGroups = numel(session.extracellular.electrodeGroups);
    %session.extracellular.spikeGroups = session.extracellular.electrodeGroups;
    %session.extracellular.nSpikeGroups = session.extracellular.nElectrodeGroups;
end
if ~isfield(session,'extracellular') || (isfield(session,'extracellular') && (~isfield(session.extracellular,'leastSignificantBit')) || isempty(session.extracellular.leastSignificantBit))
    session.extracellular.leastSignificantBit = 0.195; % (in �V) Intan = 0.195, Amplipex = 0.3815
end
if ~isfield(session,'extracellular') || (isfield(session,'extracellular') && (~isfield(session.extracellular,'probeDepths')) || isempty(session.extracellular.probeDepths))
    session.extracellular.probeDepths = 0;
end
if ~isfield(session,'extracellular') || (isfield(session,'extracellular') && (~isfield(session.extracellular,'precision')) || isempty(session.extracellular.precision))
    session.extracellular.precision = 'int16';
end

% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Spike sorting
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% You can have multiple sets of spike sorted data. 
% The first set is loaded by default
if ~isfield(session,'spikeSorting')
    % Looks for a Kilosort output folder (generated by the KiloSortWrapper)
%     kiloSortFolder = dir('Kilosort_*');
%     % Extract only those that are directories.
%     kiloSortFolder = kiloSortFolder(kiloSortFolder.isdir);
    if ~isempty(kiloSortFolder)
        relativePath = kiloSortFolder;
    else
        relativePath = ''; % Relative path to the clustered data (here assumed to be the basepath)
    end
    % Verify that the path contains Kilosort and phy output files
    if exist(fullfile(basepath, kiloSortFolder,'spike_times.npy'),'file')
        % Phy and KiloSort 
        disp('Spike sorting data detected: Phy')
        session.spikeSorting{1}.relativePath = kiloSortFolder;
        session.spikeSorting{1}.format = 'Phy';
        session.spikeSorting{1}.method = 'KiloSort';
        session.spikeSorting{1}.channels = [];
        session.spikeSorting{1}.manuallyCurated = 1;
        session.spikeSorting{1}.notes = '';
    end
end
if exist('kiloSortFolder','var')
    relativePath = kiloSortFolder;
    session.spikeSorting{1}.relativePath = kiloSortFolder;
end

% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Default brain regions 
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Brain regions  must be defined as index 1. Can be specified on a channel or electrode group basis (below example for CA1 across all channels)
session.brainRegions.(brainRegion).channels = 1:64; % Brain region acronyms from Allan institute: http://atlas.brain-map.org/atlas?atlas=1)
session.brainRegions.(brainRegion).electrodeGroups = electrodeGroup; 


% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Channel coordinates
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
if ~isfield(session,'extracellular') && ~isfield(session.extracellular,'chanCoords') 
    session.extracellular.chanCoords.layout = 'poly5'; % Probe layout: linear,staggered,poly2,edge,poly3,poly5
    %session.extracellular.chanCoords.verticalSpacing = 200; % (�m) Vertical spacing between sites.
end


% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Kilosort
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
if ~exist('relativePath','var')
    kiloSortFolder = dir('Kilosort_*');
    % Extract only those that are directories.
    kiloSortFolder = kiloSortFolder(kiloSortFolder.isdir);
    if ~isempty(kiloSortFolder)
        relativePath = kiloSortFolder.name;
    else
        relativePath = ''; % Relative path to the clustered data (here assumed to be the basepath)
    end
end
%rezFile = dir(fullfile(basepath,relativePath,'rez*.mat'));
rezFile = dir(fullfile(basepath,'rez*.mat'));
if ~isempty(rezFile)
    rezFile = rezFile.name;
    session = loadKiloSortMetadata(session,rezFile);  
end

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% sessionInfo and xml (including skipped and dead channels)
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
if exist(fullfile(session.general.basePath,[session.general.name,'.sessionInfo.mat']),'file')
    disp('Loading buzcode sessionInfo metadata')
    load(fullfile(session.general.basePath,[session.general.name,'.sessionInfo.mat']),'sessionInfo')
    if sessionInfo.spikeGroups.nGroups>0
        session.extracellular.nSpikeGroups = sessionInfo.spikeGroups.nGroups; % Number of spike groups
        session.extracellular.spikeGroups.channels = sessionInfo.spikeGroups.groups; % Spike groups
    else
        warning('No spike groups exist in the xml. Anatomical groups used instead')
        session.extracellular.nSpikeGroups = size(sessionInfo.AnatGrps,2); % Number of spike groups
        session.extracellular.spikeGroups.channels = {sessionInfo.AnatGrps.Channels}; % Spike groups
    end
    if isfield(sessionInfo,'AnatGrps')
        session.extracellular.nElectrodeGroups = size(sessionInfo.AnatGrps,2); % Number of electrode groups
        session.extracellular.electrodeGroups.channels = {sessionInfo.AnatGrps.Channels}; % Electrode groups
    else
        session.extracellular.nElectrodeGroups = session.extracellular.nSpikeGroups; % Number of electrode groups
        session.extracellular.electrodeGroups.channels = session.extracellular.spikeGroups.channels; % Electrode groups
    end
    session.extracellular.sr = sessionInfo.rates.wideband; % Sampling rate of dat file
    session.extracellular.srLfp = sessionInfo.rates.lfp; % Sampling rate of lfp file
    session.extracellular.nChannels = sessionInfo.nChannels; % Number of channels
    % Changing index from 0 to 1:
    session.extracellular.electrodeGroups.channels=cellfun(@(x) x+1,session.extracellular.electrodeGroups.channels,'un',0);
    session.extracellular.spikeGroups.channels=cellfun(@(x) x+1,session.extracellular.spikeGroups.channels,'un',0);
    
elseif exist('LoadXml.m','file') && exist(fullfile(session.general.basePath,[session.general.name, '.xml']),'file')
    disp('Loading Neurosuite xml file metadata : ' )
    sessionInfo = LoadXml(fullfile(session.general.basePath,[session.general.name, '.xml']));
    if isfield(sessionInfo,'SpkGrps')
        session.extracellular.nSpikeGroups = length(sessionInfo.SpkGrps); % Number of spike groups
        session.extracellular.spikeGroups.channels = {sessionInfo.SpkGrps.Channels}; % Spike groups
    elseif isfield(sessionInfo,'AnatGrps')
        disp('No spike groups exist in the xml. Anatomical groups used instead')
        session.extracellular.nSpikeGroups = size(sessionInfo.AnatGrps,2); % Number of spike groups
        session.extracellular.spikeGroups.channels = {sessionInfo.AnatGrps.Channels}; % Spike groups
    else
        warning(['No spike groups or Anatomical groups exist in detected xml file: ' session.general.name, '.xml'])
        return
    end
    session.extracellular.nElectrodeGroups = size(sessionInfo.AnatGrps,2); % Number of electrode groups
    session.extracellular.electrodeGroups.channels = {sessionInfo.AnatGrps.Channels}; % Electrode groups
    session.extracellular.sr = sessionInfo.SampleRate; % Sampling rate of dat file
    session.extracellular.srLfp = sessionInfo.lfpSampleRate; % Sampling rate of lfp file
    session.extracellular.nChannels = sessionInfo.nChannels; % Number of channels
    % Changing index from 0 to 1:
    session.extracellular.electrodeGroups.channels=cellfun(@(x) x+1,session.extracellular.electrodeGroups.channels,'un',0);
    session.extracellular.spikeGroups.channels=cellfun(@(x) x+1,session.extracellular.spikeGroups.channels,'un',0);
    
else
    warning('No sessionInfo.mat or xml file detected')
    sessionInfo = [];
end

if (~isfield(session.general,'date') || isempty(session.general.date)) && isfield(sessionInfo,'Date')
    session.general.date = sessionInfo.Date;
end
if isfield(session,'extracellular') && isfield(session.extracellular,'nChannels')
    fullpath = fullfile(session.general.basePath,[session.general.name,'.dat']);
    if exist(fullpath,'file')
        temp2_ = dir(fullpath);
        session.extracellular.nSamples = temp2_.bytes/session.extracellular.nChannels/2;
        session.general.duration = session.extracellular.nSamples/session.extracellular.sr;
    end
end

% Importing channel tags from sessionInfo
if isfield(sessionInfo,'badchannels')
    if isfield(session,'channelTags') && isfield(session.channelTags,'Bad')
        session.channelTags.Bad.channels = unique([session.channelTags.Bad.channels,sessionInfo.badchannels+1]);
    else
        session.channelTags.Bad.channels = sessionInfo.badchannels+1;
    end
end

if isfield(sessionInfo,'channelTags')
    tagNames = fieldnames(sessionInfo.channelTags);
    for iTag = 1:length(tagNames)
        if isfield(session,'channelTags') && isfield(session.channelTags,tagNames{iTag})
            session.channelTags.(tagNames{iTag}).channels = unique([session.channelTags.(tagNames{iTag}).channels,sessionInfo.channelTags.(tagNames{iTag})+1]);
        else
            session.channelTags.(tagNames{iTag}).channels = sessionInfo.channelTags.(tagNames{iTag})+1;
        end
    end
end

% Importing brain regions from sessionInfo
if isfield(sessionInfo,'region')
    load BrainRegions.mat
    regionNames = unique(cellfun(@num2str,sessionInfo.region,'uni',0));
    regionNames(cellfun('isempty',regionNames)) = [];
    for iRegion = 1:length(regionNames)
        if any(strcmp(regionNames{iRegion},BrainRegions(:,2)))
            session.brainRegions.(regionNames{iRegion}).channels = find(strcmp(regionNames{iRegion},sessionInfo.region));
        elseif strcmp(lower(regionNames{iRegion}),'hpc')
            session.brainRegions.HIP.channels = find(strcmp(regionNames{iRegion},sessionInfo.region));
        else
            disp(['Brain region does not exist in the Allen Brain Atlas: ' regionNames{iRegion}])
            regionName = regexprep(regionNames{iRegion}, {'[%() ]+', '_+$'}, {'_', ''});
            tagName = ['brainRegion_', regionName];
            if ~isfield(session,'channelTags') || all(~strcmp(tagName,fieldnames(session.channelTags)))
                disp(['Creating a channeltag with assigned channels: ' tagName])
                session.channelTags.(tagName).channels = find(strcmp(regionNames{iRegion},sessionInfo.region));
            end
        end
    end
end

% Epochs derived from MergePoints
if exist(fullfile(basepath,[session.general.name,'.MergePoints.events.mat']),'file')
    load(fullfile(basepath,[session.general.name,'.MergePoints.events.mat']),'MergePoints')
    for i = 1:size(MergePoints.foldernames,2)
        session.epochs{i}.name =  MergePoints.foldernames{i};
        session.epochs{i}.startTime =  MergePoints.timestamps(i,1);
        session.epochs{i}.stopTime =  MergePoints.timestamps(i,2);
    end
end

% Creating empty epoch if none exist
if ~isfield(session,'epochs')
    session.epochs{1}.name = session.general.name;
    session.epochs{1}.startTime =  0;
end

% % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Importing time series from intan metadatafile info.rhd
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
try
    session = loadIntanMetadata(session);
catch
    warning('Failed to get intan metadata')
end

% Finally show GUI if requested by user
if showGUI
    session = gui_session(session);
end