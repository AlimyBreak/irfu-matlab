% Execute a "S/W mode" as (indirectly) specified by the CLI arguments.
% This function should be agnostic of CLI syntax.
%
%
% Author: Erik P G Johansson, IRF-U, Uppsala, Sweden
% First created 2016-06-09
%
%
% ARGUMENTS AND RETURN VALUES
% ===========================
% SwModeInfo
% InputFilePathMap  : containers.Map with
%    key   = prodFuncInputKey
%    value = Path to input file
% OutputFilePathMap : containers.Map with
%    key   = prodFuncOutputKey
%    value = Path to output file
%
%
% "BUGS"
% ======
% - Sets GlobalAttributes.Generation_date in local time (no fixed time zone).
% - Calls derive_output_dataset_GlobalAttributes for ALL input dataset and uses the result for ALL output datasets.
%   ==> If a S/W mode has multiple output datasets based on different sets of input datasets, then the GlobalAttributes
%   might be wrong. Should ideally be run on the exact input datasets (~EIn PDs) used to produce a specific output
%   dataset.
%
function execute_sw_mode(SwModeInfo, InputFilePathMap, OutputFilePathMap, masterCdfDir, calibrationDir, SETTINGS)
%
% QUESTION: How verify dataset ID and dataset version against constants?
%    NOTE: Need to read CDF first.
%    NOTE: Need S/W mode.
%
% PROPOSAL: Verify output zVariables against master CDF zVariable dimensions (accessible with dataobj, even for zero records).
%   PROPOSAL: function matchesMaster(DataObj, MasterDataobj)
%       PRO: Want to use dataobj to avoid reading file (input dataset) twice.
%
% QUESTION: What should be the relationship between data manager and S/W modes really?
%           Should data manager check anything?
%
% NOTE: Things that need to be done when writing PDV-->CDF
%       Read master CDF file.
%       Compare PDV variables with master CDF variables (only write a subset).
%       Check variable types, sizes against master CDF.
%       Write GlobalAttributes: Calibration_version, Parents, Parent_version, Generation_date, Logical_file_id,
%           Software_version, SPECTRAL_RANGE_MIN/-MAX (optional?), TIME_MIN/-MAX
%       Write VariableAttributes: pad value? (if master CDF does not contain a correct value), SCALE_MIN/-MAX
%
% PROPOSAL: BUG FIX: Move global attributes into PDs somehow to let the processing functions collect the values during processing?
%   PROPOSAL: Have PDs include global attributes in new struct structure.
%             EIn PD:            EInPD(GlobalAttributes,          zVariables)   // All input dataset GAs.
%             Intermediary PDs:     PD(GlobalAttributesCellArray, data)         // All input datasets GAs (multiple datasets).
%             EOut PDs:         EOutPD(GlobalAttributesSubset,    data)         // Only those GAs that should be set. Should have been "collected" at this stage.
%       PROBLEM: When collecting lists of GAs, must handle any overlap of input datasets when merging lists.
%           Ex: (EIn1+EIn2-->Interm1; EIn1+EIn2-->Interm2; Interm1+Interm2-->EOut)
%
% PROPOSAL: Print variable statistics also for zVariables which are created with fill values.
%   NOTE: These do not use NaN, but fill values.



GlobalAttributesCellArray = {};   % Use cell array since CDF global attributes may in principle contain different sets of attributes (field names).

Cal = bicas.calib(calibrationDir, SETTINGS);



% ASSERTION: Check that all input & output dataset paths (strings) are unique.
% NOTE: Manually entering CLI argument, or copy-pasting BICAS call, can easily lead to reusing the same path by mistake,
% and e.g. overwriting an input file.
datasetFileList = [InputFilePathMap.values(), OutputFilePathMap.values()];
assert(numel(unique(datasetFileList)) == numel(datasetFileList), 'BICAS:execute_sw_mode:CLISyntax', ...
    'Input and output dataset paths are not all unique. This hints of a manual mistake in the CLI arguments in call to BICAS.')



%=================================
% READ CDFs
% ---------
% Iterate over all the INPUT CDFs
%=================================
InputDatasetsMap = containers.Map();
for i = 1:length(SwModeInfo.inputsList)
    prodFuncInputKey = SwModeInfo.inputsList(i).prodFuncInputKey;
    inputFilePath    = InputFilePathMap(prodFuncInputKey);
    
    %=======================
    % Read dataset CDF file
    %=======================
    [Zv, GlobalAttributes]             = read_dataset_CDF(inputFilePath);
    InputDatasetsMap(prodFuncInputKey) = struct('Zv', Zv, 'Ga', GlobalAttributes);
    
    
    
    %===========================================
    % ASSERTIONS: Check GlobalAttributes values
    %===========================================
    % NOTE: Can not use bicas.proc_utils.assert_struct_num_fields_have_same_N_rows(Zv) since not all zVariables have same number of
    % records. Ex: Metadata such as ACQUISITION_TIME_UNITS.
    if isfield(GlobalAttributes, 'Dataset_ID')
        datasetId = GlobalAttributes.Dataset_ID{1};
    else
        error('BICAS:execute_sw_mode:Assertion:DatasetFormat', ...
            'Input dataset does not contain (any accepted variation of) the global attribute Dataset_ID.\n    File: "%s"', ...
            inputFilePath)
    end
    bicas.utils.assert_strings_equal(...
        SETTINGS.get_fv('INPUT_CDF_ASSERTIONS.STRICT_DATASET_ID'), ...
        {GlobalAttributes.Dataset_ID{1}, SwModeInfo.inputsList(i).datasetId}, ...
        sprintf('The input CDF file''s stated DATASET_ID does not match the value expected for the S/W mode.\n    File: %s\n    ', inputFilePath))



    GlobalAttributesCellArray{end+1} = GlobalAttributes;
end



globalAttributesSubset = derive_output_dataset_GlobalAttributes(GlobalAttributesCellArray, SETTINGS);



%==============
% PROCESS DATA
%==============
OutputDatasetsMap = SwModeInfo.prodFunc(InputDatasetsMap, Cal);



%==================================
% WRITE CDFs
% ----------
% Iterate over all the OUTPUT CDFs
%==================================
for iOutputCdf = 1:length(SwModeInfo.outputsList)
    OutputInfo = SwModeInfo.outputsList(iOutputCdf);
    
    prodFuncOutputKey = OutputInfo.prodFuncOutputKey;
    outputFilePath    = OutputFilePathMap(prodFuncOutputKey);

    %========================
    % Write dataset CDF file
    %========================
    masterCdfPath = fullfile(...
        masterCdfDir, ...
        bicas.get_master_CDF_filename(OutputInfo.datasetId, OutputInfo.skeletonVersion));
    write_dataset_CDF ( ...
        OutputDatasetsMap(OutputInfo.prodFuncOutputKey), globalAttributesSubset, outputFilePath, masterCdfPath, OutputInfo.datasetId, SETTINGS );
end



end   % execute_sw_mode







function GlobalAttributesSubset = derive_output_dataset_GlobalAttributes(GlobalAttributesCellArray, SETTINGS)
% Function for global attributes for an output dataset from the global attributes of multiple input datasets (if there
% are several).
%
% PGA = parents' GlobalAttributes.
%
% RETURN VALUE
% ============
% GlobalAttributesSubset : Struct where each field name corresponds to a CDF global atttribute.
%                          NOTE: Deviates from the usual variable naming conventions. GlobalAttributesSubset field names
%                          have the exact names of CDF global attributes.
%

ASSERT_MATCHING_TEST_ID = SETTINGS.get_fv('INPUT_CDF_ASSERTIONS.MATCHING_TEST_ID');

GlobalAttributesSubset.Parents        = {};            % Array in which to collect value for this file's GlobalAttributes (array-sized GlobalAttribute).
GlobalAttributesSubset.Parent_version = {};
pgaTestIdList   = {};   % List = List with one value per parent.
pgaProviderList = {};
for i = 1:length(GlobalAttributesCellArray)
    GlobalAttributesSubset.Parents       {end+1} = ['CDF>', GlobalAttributesCellArray{i}.Logical_file_id{1}];
    
    % NOTE: ROC DFMD is not completely clear on which version number should be used.
    GlobalAttributesSubset.Parent_version{end+1} = GlobalAttributesCellArray{i}.Data_version{1};
    
    pgaTestIdList                        {end+1} = GlobalAttributesCellArray{i}.Test_id{1};
    pgaProviderList                      {end+1} = GlobalAttributesCellArray{i}.Provider{1};
end

% NOTE: Test_id values can legitimately differ. E.g. "eeabc1edba9d76b08870510f87a0be6193c39051" and "eeabc1e".
bicas.utils.assert_strings_equal(0,                       pgaProviderList, 'The input CDF files'' GlobalAttribute "Provider" values differ.')
bicas.utils.assert_strings_equal(ASSERT_MATCHING_TEST_ID, pgaTestIdList,   'The input CDF files'' GlobalAttribute "Test_id" values differ.')

% IMPLEMENTATION NOTE: Uses shortened "Test id" value in case it is a long one, e.g. "eeabc1edba9d76b08870510f87a0be6193c39051". Uncertain
% how "legal" that is but it seems to be at least what people use in the filenames.
% IMPLEMENTATION NOTE: Does not assume a minimum length for TestId since empty Test_id strings have been observed in
% datasets. /2020-01-07
GlobalAttributesSubset.Provider = pgaProviderList{1};
GlobalAttributesSubset.Test_Id  = pgaTestIdList{1}(1:min(7, length(pgaTestIdList{1})));

end







function [Zvs, GlobalAttributes] = read_dataset_CDF(filePath)
% Read elementary input process data from a CDF file. Copies all zVariables into fields of a regular structure.
%
%
% RETURN VALUES
% =============
% Zvs              : Struct with one field per zVariable (using the same name). The content of every such field equals the
%                    content of the corresponding zVar.
% GlobalAttributes : Struct returned from "dataobj".
%
%
% NOTE: Fill & pad values are replaced with NaN for numeric data types.
%       Other CDF data (attributes) are ignored.
% NOTE: Uses irfu-matlab's dataobj for reading the CDF file.

% NOTE: HK TIME_SYNCHRO_FLAG can be empty.



%===========
% Read file
%===========
bicas.logf('info', 'Reading CDF file: "%s"', filePath)
DataObj = dataobj(filePath);                 % do=dataobj, i.e. irfu-matlab's dataobj!!!



%=========================================================================
% Copy zVariables (only the data) into analogous fields in smaller struct
%=========================================================================
bicas.log('info', 'Converting dataobj (CDF data structure) to PDV.')
Zvs               = struct();
ZvsLog            = struct();   % zVariables for logging.
zVariableNameList = fieldnames(DataObj.data);
for i = 1:length(zVariableNameList)
    zvName  = zVariableNameList{i};
    zvValue = DataObj.data.(zvName).data;
    
    ZvsLog.(zvName) = zvValue;
    
    %=================================================
    % Replace fill/pad values with NaN for FLOAT data
    %=================================================
    % QUESTION: How does/should this work with integer fields that should also be stored as integers internally?!!!
    %    Ex: ACQUISITION_TIME, Epoch.
    % QUESTION: How distinguish integer zVariables that could be converted to floats (and therefore use NaN)?
    if isfloat(zvValue)
        [fillValue, padValue] = get_fill_pad_values(DataObj, zvName);
        if ~isempty(fillValue)
            % CASE: There is a fill value.
            zvValue = bicas.utils.replace_value(zvValue, fillValue, NaN);
        end
        zvValue = bicas.utils.replace_value(zvValue, padValue,  NaN);
    else
        % Disable?! Only print warning if finds fill value which is not replaced?
        %bicas.logf('warning', 'Can not handle replace fill/pad values for zVariable "%s" when reading "%s".', zVariableName, filePath))
    end
    
    Zvs.(zvName) = zvValue;
end



% Log data read from CDF file
bicas.proc_utils.log_zVars(ZvsLog)



% NOTE: At least test files
% solo_L1R_rpw-tds-lfm-cwf-e_20190523T080316-20190523T134337_V02_les-7ae6b5e.cdf
% solo_L1R_rpw-tds-lfm-rswf-e_20190523T080316-20190523T134337_V02_les-7ae6b5e.cdf
% do not contain "DATASET_ID", only "Dataset_ID".
%
% NOTE: Has not found document that specifies the global attribute. /2020-01-16
% https://gitlab.obspm.fr/ROC/RCS/BICAS/issues/7#note_11016
% states that the correct string is "Dataset_ID".
GlobalAttributes = bicas.utils.normalize_struct_fieldnames(DataObj.GlobalAttributes, ...
    {{{'DATASET_ID', 'Dataset_ID'}, 'Dataset_ID'}});

bicas.logf('info', 'File''s Global attribute: Dataset_ID       = "%s"', GlobalAttributes.Dataset_ID{1})
bicas.logf('info', 'File''s Global attribute: Skeleton_version = "%s"', GlobalAttributes.Skeleton_version{1})

end



function write_dataset_CDF(...
    ZvsSubset, GlobalAttributesSubset, outputFile, masterCdfPath, datasetId, SETTINGS)
%
% Function that writes one ___DATASET___ CDF file.
%

%==========================================================================
% This function needs GlobaAttributes values from the input files:
%    One value per file:      Data_version (for setting Parent_version).
%    One value for all files: Test_id
%    Data_version ??!!
%
% PROPOSAL: Accept GlobalAttributes for all input datasets?!
% PROBLEM: Too many arguments.
% QUESTION: Should function find the master CDF file itself?
%   Function needs the dataset ID for it anyway.
%   Function should check the master file anyway: Assert existence, GlobalAttributes (dataset ID, SkeletonVersion, ...)
%==========================================================================



%======================
% Read master CDF file
%======================
bicas.logf('info', 'Reading master CDF file: "%s"', masterCdfPath)
DataObj = dataobj(masterCdfPath);
ZvsLog  = struct();   % zVars for logging.

%=============================================================================================
% Iterate over all OUTPUT PD field names (~zVariables) - Set corresponding dataobj zVariables
%=============================================================================================
% NOTE: Only sets a SUBSET of the zVariables in master CDF.
pdFieldNameList = fieldnames(ZvsSubset);
bicas.log('info', 'Converting PDV to dataobj (CDF data structure)')
for iPdFieldName = 1:length(pdFieldNameList)
    zvName = pdFieldNameList{iPdFieldName};
    
    % ASSERTION: Master CDF already contains the zVariable.
    if ~isfield(DataObj.data, zvName)
        error('BICAS:execute_sw_mode:Assertion:SWModeProcessing', ...
        'Trying to write to zVariable "%s" that does not exist in the master CDF file.', zvName)
    end
    
    zvValue = ZvsSubset.(zvName);
    ZvsLog.(zvName)            = zvValue;
    
    % Prepare PDV zVariable value:
    % (1) Replace NaN-->fill value
    % (2) Convert to the right MATLAB class.
    if isfloat(zvValue)
        [fillValue, ~] = get_fill_pad_values(DataObj, zvName);
        zvValue  = bicas.utils.replace_value(zvValue, NaN, fillValue);
    end
    matlabClass   = bicas.utils.convert_CDF_type_to_MATLAB_class(DataObj.data.(zvName).type, 'Permit MATLAB classes');
    zvValue = cast(zvValue, matlabClass);
    
    % Set zVariable.
    DataObj.data.(zvName).data = zvValue;
end



% Log data to be written to CDF file.
bicas.proc_utils.log_zVars(ZvsLog)



%==========================
% Set CDF GlobalAttributes
%==========================
DataObj.GlobalAttributes.Software_name       = SETTINGS.get_fv('SWD.identification.name');
DataObj.GlobalAttributes.Software_version    = SETTINGS.get_fv('SWD.release.version');
DataObj.GlobalAttributes.Calibration_version = SETTINGS.get_fv('OUTPUT_CDF.GLOBAL_ATTRIBUTES.Calibration_version');         % "Static"?!!
DataObj.GlobalAttributes.Generation_date     = datestr(now, 'yyyy-mm-ddTHH:MM:SS');         % BUG? Assigns local time, not UTC!!! ROC DFMD does not mention time zone.
DataObj.GlobalAttributes.Logical_file_id     = get_logical_file_id(...
    datasetId, GlobalAttributesSubset.Test_Id, ...
    GlobalAttributesSubset.Provider, ...
    SETTINGS.get_fv('OUTPUT_CDF.DATA_VERSION'));
DataObj.GlobalAttributes.Parents             = GlobalAttributesSubset.Parents;
DataObj.GlobalAttributes.Parent_version      = GlobalAttributesSubset.Parent_version;
DataObj.GlobalAttributes.Data_version        = SETTINGS.get_fv('OUTPUT_CDF.DATA_VERSION');     % ROC DFMD says it should be updated in a way which can not be automatized?!!!
DataObj.GlobalAttributes.Provider            = GlobalAttributesSubset.Provider;             % ROC DFMD contradictive if it should be set.
if SETTINGS.get_fv('OUTPUT_CDF.GLOBAL_ATTRIBUTES.SET_TEST_ID')
    DataObj.GlobalAttributes.Test_id         = GlobalAttributesSubset.Test_Id;              % ROC DFMD says that it should really be set by ROC.
end
%DataObj.GlobalAttributes.SPECTRAL_RANGE_MIN
%DataObj.GlobalAttributes.SPECTRAL_RANGE_MAX
%DataObj.GlobalAttributes.TIME_MIN
%DataObj.GlobalAttributes.TIME_MAX
%DataObj.GlobalAttribute CAVEATS ?!! ROC DFMD hints that value should not be set dynamically. (See meaning of non-italic black text for global attribute name in table.)



%==============================================
% Handle still-empty zVariables (zero records)
%==============================================
for fn = fieldnames(DataObj.data)'
    zvName = fn{1};
    
    if isempty(DataObj.data.(zvName).data)
        % CASE: zVariable has zero records, indicating that should have been set using PDV field.
        
        logMsg = sprintf(['Master CDF contains zVariable "%s" which has not been set (i.e. it has zero records) after adding ', ...
            'processing data. This should only happen for incomplete processing.'], ...
            zvName);
        
        matlabClass  = bicas.utils.convert_CDF_type_to_MATLAB_class(DataObj.data.(zvName).type, 'Permit MATLAB classes');
        isNumericZVar = isnumeric(cast(0.000, matlabClass));

        if isNumericZVar && SETTINGS.get_fv('OUTPUT_CDF.EMPTY_NUMERIC_ZVARIABLES_SET_TO_FILL')
            bicas.log('warning', logMsg)

%             % ASSERTION: Require numeric type.
%             if ~isnumeric(cast(0.000, matlabClass))
%                 error('BICAS:sw_execute_sw_mode:SWModeProcessing', ...
%                     'zVariable "%s" is non-numeric. Can not set it to correctly-sized data with fill values (not implemented).', zVariableName)
%             end
            
            %========================================================
            % Create correctly-sized zVariable data with fill values
            %========================================================
            % NOTE: Assumes that
            % (1) there is a PD fields/zVariable Epoch, and
            % (2) this zVariable should have as many records as Epoch.
            bicas.logf('warning', 'Setting numeric master/output CDF zVariable "%s" to presumed correct size using fill values due to setting.', zvName)
            nEpochRecords = size(ZvsSubset.Epoch, 1);
            [fillValue, ~] = get_fill_pad_values(DataObj, zvName);
            zVariableSize = [nEpochRecords, DataObj.data.(fn{1}).dim];
            zvValue = cast(zeros(zVariableSize), matlabClass);
            zvValue = bicas.utils.replace_value(zvValue, 0, fillValue);
            
            DataObj.data.(zvName).data = zvValue;

        elseif ~isNumericZVar && SETTINGS.get_fv('OUTPUT_CDF.EMPTY_NONNUMERIC_ZVARIABLES_IGNORE')
            bicas.logf('warning', ...
                'Ignoring empty non-numeric master CDF zVariable "%s" due to setting OUTPUT_CDF.EMPTY_NONNUMERIC_ZVARIABLES_IGNORE.', ...
                zvName)

        else
            error('BICAS:execute_sw_mode:SWModeProcessing', logMsg)
        end
    end
end

settingOverwritePolicy   = SETTINGS.get_fv('OUTPUT_CDF.OVERWRITE_POLICY');
settingWriteFileDisabled = SETTINGS.get_fv('OUTPUT_CDF.WRITE_FILE_DISABLED');


%==============================
% Checks before writing to CDF
%==============================
% Check if file writing is deliberately disabled.
if settingWriteFileDisabled
    bicas.logf('warning', 'Writing output CDF file is disabled via setting OUTPUT_CDF.WRITE_FILE_DISABLED.')
    return
end
% UI ASSERTION: Check for directory collision. Always error.
if exist(outputFile, 'dir')     % Checks for directory.
    error('BICAS:execute_sw_mode', 'Intended output dataset file path matches a pre-existing directory.')
end

% Behaviour w.r.t. output file path collision with pre-existing file.
if exist(outputFile, 'file')    % Checks for file and directory.
    switch(settingOverwritePolicy)
        case 'ERROR'
            % UI ASSERTION
            error('BICAS:execute_sw_mode', ...
                'Intended output dataset file path "%s" matches a pre-existing file. Setting OUTPUT_CDF.OVERWRITE_POLICY is set to prohibit overwriting.', ...
                outputFile)
        case 'OVERWRITE'
            bicas.logf('warning', ...
                'Intended output dataset file path "%s"\nmatches a pre-existing file. Setting OUTPUT_CDF.OVERWRITE_POLICY is set to permit overwriting.\n', ...
                outputFile)
        otherwise
            error('BICAS:execute_sw_mode:ConfigurationBug', 'Illegal setting value OUTPUT_CDF.OVERWRITE_POLICY="%s".', settingOverwritePolicy)
    end
end

%===========================================
% Write to CDF file using write_CDF_dataobj
%===========================================
bicas.logf('info', 'Writing dataset CDF file: %s', outputFile)
bicas.utils.write_CDF_dataobj( ...
    outputFile, ...
    DataObj.GlobalAttributes, ...
    DataObj.data, ...
    DataObj.VariableAttributes, ...
    DataObj.Variables ...
    )

end







function logicalFileId = get_logical_file_id(datasetId, testId, provider, dataVersion)
% Construct a "Logical_file_id" as defined in the ROC DFMD
% "The name of the CDF file without the ‘.cdf’ extension, using the file naming convention."


bicas.assert_DATASET_ID(datasetId)

if ~ischar(dataVersion ) || length(dataVersion)~=2
    error('BICAS:execute_sw_mode:Assertion:IllegalArgument', 'Illegal dataVersion')
end

providerParts = strsplit(provider, '>');
logicalFileId = [datasetId, '_', testId, '_', providerParts{1}, '_V', dataVersion];
end






% fillValue : Empty if there is no fill value.
%
function [fillValue, padValue] = get_fill_pad_values(do, zVariableName)
% NOTE: Uncertain how it handles the absence of a fill value. (Or is fill value mandatory?)
% PROPOSAL: Remake into general-purpose function.
% PROPOSAL: Remake into just using the do.Variables array?
%    NOTE: Has to derive CDF variable type from do.Variables too.
% PROPOSAL: Incorporate into dataobj?! Isn't there a buggy function/method there already?

fillValue = getfillval(do, zVariableName);        % NOTE: Special function for dataobj.
% NOTE: For unknown reasons, the fill value for tt2000 zVariables (or at least "Epoch") is stored as a UTC(?) string.
if strcmp(do.data.(zVariableName).type, 'tt2000')
    fillValue = spdfparsett2000(fillValue);   % NOTE: Uncertain if this is the correct conversion function.
end

iZVariable = strcmp(do.Variables(:,1), zVariableName);
padValue   = do.Variables{iZVariable, 9};
% Comments in "spdfcdfinfo.m" should indirectly imply that column 9 is pad values since the structure/array
% commented on should be identical.
end

