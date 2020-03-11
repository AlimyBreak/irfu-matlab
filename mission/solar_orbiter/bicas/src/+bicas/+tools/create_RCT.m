function create_RCT(rctMasterCdfFile, destDir)
%
% Script/utility for creating the ROC-SGSE and RODP BIAS RCTs. The code reads a master file, and using it, creates a
% version with calibration data added to it.
% NOTE: The actual calibration data is hard-coded in this file.
%
% RCT = RPW Calibration Table
%
%
% ARGUMENTS
% =========
% rctMasterCdfFile       : Path to empty BIAS master RCT CDF file (existing) to read.
% destDir                : Path to directory of the RCT file to be created (compliant filename will be generated by the function).
%                          NOTE: Any pre-existing destination file will be overwritten.
%
%
% RATIONALE
% =========
% An alternative to using this function is to modify the master RCT manually with cdfedit (from NASA SPDF's CDF
% software). Using this function is however better because
% (1) There are two RCTs with identical calibration data content (ROC-SGSE + RODP),
% (2) it saves work when updating the master RCT .cdf (generated from master Excel file), including making inofficial
%     intermediate versions in the master (e.g. fixing typos)
% (2) it is easier to edit (compared to using cdfedit), e.g. (a) editing existing information as well as (b) adding records
% (3) it is easier to edit if the RCT is extended with more data by changing the format (in particular more transfer
%     functions, by some multiple).
% (4) it could be modified to read data from external files, e.g. text files.
%
%
% RCT FILENAME CONVENTION
% =======================
% See implementation for comments.
% See comments for settings PROCESSING.RCT_REGEXP.* (all RCTs), in bicas.create_default_SETTINGS.
%
%
% Author: Erik P G Johansson, IRF, Uppsala, Sweden
% First created 2018-03-09


% RCTs in DataPool git repository 2019-01-14 (commit 50cc3d8):
%  ROC-SGSE_CAL_RCT-BIAS_V01.xlsx
%  ROC-SGSE_CAL_RCT-BIAS_V02.xlsx        <--- Where is this now?
%  ROC-SGSE_CAL_RCT-LFR-BIAS_V01.xlsx
%  ROC-SGSE_CAL_RCT-LFR-SCM_V01.xlsx
%  ROC-SGSE_CAL_RCT-LFR-VHF_V01.xlsx
%  ROC-SGSE_CAL_RCT-TDS-LFM-CWF-B_V01.xlsx
%  ROC-SGSE_CAL_RCT-TDS-LFM-CWF-E_V01.xlsx
%  ROC-SGSE_CAL_RCT-TDS-LFM-RSWF-B_V01.xlsx
%  ROC-SGSE_CAL_RCT-TDS-LFM-RSWF-E_V01.xlsx
%  ROC-SGSE_CAL_RCT-TDS-SURV-SWF-B_V01.xlsx
%  ROC-SGSE_CAL_RCT-TDS-SURV-SWF-E_V01.xlsx
%  SOLO_CAL_RCT-BIAS_V01.xlsx
%  SOLO_CAL_RCT-SCM_V01.xlsx
%  SOLO_CAL_RCT-TDS-LFM-RSWF-B_V01.xlsx
%  SOLO_CAL_RCT-TDS-LFM-RSWF-E_V01.xlsx
%  SOLO_CAL_RCT-TDS-SURV-SWF-B_V01.xlsx
%
% MANUAL CALL: bicas.tools.create_RCT('/nonhome_data/work_files/SOLAR_ORBITER/skeletons_BIAS_RCT/SOLO_CAL_RCT-BIAS_V01.cdf', '/nonhome_data/work_files/SOLAR_ORBITER/bicas_calibration_files/')



% TODO-NEED-INFO: How set time stamps?
%   NOTE: Time stamps are not copied, nor modifications of existing time stamps. Can therefor not just reduce to relative times.
% PROPOSAL: Change function name: Something which implies using a master file and "filling it".
% PROPOSAL: Somehow separate the code with the hardcoded data into a separate file.
    
    
    
    destPath = fullfile(destDir, get_dest_RCT_filename());
    
    ADD_DEBUG_RECORD_L = 0;
    ADD_DEBUG_RECORD_H = 0;
    
    
    %===================================================================
    % Create EMPTY (not zero-valued) variables representing zVariables.
    %===================================================================
    RctZvL.Epoch_L                  = int64( zeros(0,1));
    RctZvL.BIAS_CURRENT_OFFSET      = zeros(0,3);
    RctZvL.BIAS_CURRENT_GAIN        = zeros(0,3);
    RctZvL.TRANSFER_FUNCTION_COEFFS = zeros(0,2,8,4);
    
    RctZvH.Epoch_H  = int64( zeros(0,1));
    RctZvH.E_OFFSET = zeros(0,3);
    RctZvH.V_OFFSET = zeros(0,3);
    
    
    
    %===================================================================================================================
    % Extract from e-mail:
    % --------------------
    % Finally, I have made some fits for the other BIAS standalone tests 2016-06-21/22.
    %
    % DC single
    %            -1.041e10 s^2 + 8.148e14 s - 5.009e20
    %   ---------------------------------------------------------
    %   s^4 + 8.238e05 s^3 + 2.042e12 s^2 + 2.578e17 s + 8.556e21
    %
    % DC diff
    %             2.664e11 s^2 - 1.009e18 s - 2.311e23
    %   ---------------------------------------------------------
    %   s^4 + 3.868e06 s^3 + 7.344e12 s^2 + 4.411e18 s + 2.329e23
    %
    % AC, diff, low-gain (gamma=5)
    %            -1.946e12 s^2 - 1.365e18 s - 2.287e18
    %   -------------------------------------------------------
    %   s^4 + 3.85e06 s^3 + 4.828e12 s^2 + 2.68e17 s + 1.348e19
    %
    % AC, diff, gamma=100
    %             1.611e24 s^4 - 2.524e30 s^3 - 1.258e35 s^2 - 4.705e39 s + 2.149e40
    % ---------------------------------------------------------------------------------------
    %   s^6 + 7.211e17 s^5 + 6.418e23 s^4 + 6.497e28 s^3 + 2.755e33 s^2 + 4.817e37 s + 2.114e39
    %
    % Based on BIAS standalone calibrations 2016-06-21/22, 100 kOhm stimuli, (there is only one temperature for these tests), TEST ID=0-3
    % Fits have been made using MATLAB function invfreqs with weights = 1 for freqHz <= 199e3.
    %-------------------------------------------------------------------------------------------------------------------
    % NOTE: Above fits for DC single/diff, AC low gain (NOT AC high gain) can be re-created using
    %   * Files 20160621_FS0_EG_Test_Flight_Harness_Preamps/4-5_TRANSFER_FUNCTION/SO_BIAS_AC_VOLTAGE_ID{00..02}*.txt
    %   * N_ZEROS = 2;
    %     N_POLES = 4;
    %   * N_ITERATIONS = 30;
    %   * weights = double( (Data.freqHz <= 199e3) );
    %   * [b, a] = invfreqs(Data.z, Data.freqRps, N_ZEROS, N_POLES, weights, N_ITERATIONS);
    % NOTE: Unclear how to re-create the fit for AC high gain, but it should be similar but using file
    %   20160621_FS0_EG_Test_Flight_Harness_Preamps/4-5_TRANSFER_FUNCTION/SO_BIAS_AC_VOLTAGE_ID03*.txt
    % NOTE: All above TFs except AC diff high-gain, invert the sign at 0 Hz. This sign change appears to be wrong.
    % The source files (four) all have ~sign inversion at 10 Hz (the lowest tabulated frequency); -141-142 degrees phase
    % for both AC TFs.
    %===================================================================================================================
    RctZvL = add_RCT_zvars_L(RctZvL, int64(0), [-2.60316e-09, 4.74234e-08, 4.78828e-08]', [-1.98004e-09, -1.97993e-09, -1.98017e-09]', ...
        create_tfc_zvar_record(...
        'DC_single', {-[-5.009e20,  8.148e14, -1.041e10],                      [8.556e21, 2.578e17, 2.042e12, 8.238e05, 1]}, ...
        'DC_diff',   {-[-2.311e23, -1.009e18,  2.664e11],                      [2.329e23, 4.411e18, 7.344e12, 3.868e06, 1]}, ...
        'AC_lg',     {-[-2.287e18, -1.365e18, -1.946e12],                      [1.348e19, 2.68e17 , 4.828e12, 3.85e06,  1]}, ...
        'AC_hg',     {-[ 2.149e40, -4.705e39, -1.258e35, -2.524e30, 1.611e24], [2.114e39, 4.817e37, 2.755e33, 6.497e28, 6.418e23,  7.211e17, 1]}) ...
        );
    
    if ADD_DEBUG_RECORD_L
        % TEST: Add another record for Epoch_L.
        RctZvL = add_RCT_zvars_L(RctZvL, ...
            RctZvL.Epoch_L(end) + 1e9, ...
            RctZvL.BIAS_CURRENT_OFFSET(end)', ...
            RctZvL.BIAS_CURRENT_GAIN(end)', ...
            RctZvL.TRANSFER_FUNCTION_COEFFS(end, :,:,:) ...
            );
        warning('Creating RCT with added test data.')
    end
    
    
    
    %===================================================================================================================    
    % Values from 20160621_FS0_EG_Test_Flight_Harness_Preamps.
    % V_OFFSET values from mheader.reg6 for tests with stimuli=1e5 Ohm.
    % E_OFFSET values from mheader.reg6 for tests with stimuli=1e5 Ohm, non-inverted inputs.
    % Sign is uncertain
    % Uncertain whether it is correct to use value for stimuli=1e5 Ohm instead 1e6 Ohm.
    % Uncertain whether it is correct to use the reg6 value instead of own fit.
    %===================================================================================================================
    RctZvH = add_RCT_zvars_H(RctZvH, int64(0), -[0.001307, 0.0016914, 0.0030156]', -[0.015384, 0.01582, 0.017215]');
    if ADD_DEBUG_RECORD_H
        % TEST: Add another record for Epoch_H.
        RctZvH = add_RCT_zvars_H(RctZvH, ...
            RctZvH.Epoch_H(end) + 2e9, ...
            RctZvH.V_OFFSET(end, :)', ...
            RctZvH.V_OFFSET(end, :)');
        warning('Creating RCT with added test data.')
    end



    fprintf(1, 'Creating file "%s"\n', destPath);
    create_RCT_file(rctMasterCdfFile, destPath, RctZvL, RctZvH);
    
end





% Create RCT filename (time-stamped).
%
%
% OFFICIAL DOCUMENTATION ON RCT FILENAMING CONVENTION
% ===================================================
% See comments for bicas.create_default_SETTINGS, settings PROCESSING.RCT_REGEXP.* (all RCTs).
%
function destFilename = get_dest_RCT_filename()
    % IMPLEMENTATION NOTE: The official filenaming convention is not followed here!! Not sure how to comply with it either (which
    % receiver should the BIAS RCT specify?).
    
    destFilename = sprintf(    'SOLO_CAL_RPW_BIAS_V%s.cdf', datestr(clock, 'yyyymmddHHMM'));
end



% Create array corresponding to one CDF record of zVar TRANSFER_FUNCTION_COEFFS.
%
% ARGUMENTS
% =========
% varargin : Argument n+1 :
% cellTree : Recursive cell array which contains the same information as one record of zVar TRANSFER_FUNCTION_COEFFS.
%            Indices {}{iNumDen}(iCoeff)
%
% TFC = (zVar) TRANSFER_FUNCTION_COEFFS
%
% IMPLEMENTATION NOTE: Odd argument list
function zVarRecord = create_tfc_zvar_record(varargin)
    N_ZVAR_COEFF = 8;
    
    zVarRecord = double(zeros(1, 2, N_ZVAR_COEFF, 4));
    INDEX_LABEL_LIST = {'DC_single', 'DC_diff', 'AC_lg', 'AC_hg'};
    for i=1:4
        if strcmp(varargin{2*i-1}, INDEX_LABEL_LIST{i})
            zVarRecord(1,:,:,i) = c2a(varargin{2*i});
        end
    end
    
    % ASSERTION
    if any(any(any(~isfinite(zVarRecord))))
        error('create_RCT:Assertion', 'zVarRecord contains non-finite values.')
    end
    
    
    % Convert one description of TF into another.
    % Convert 1x2 cell array of 1D arrays --> "2D" array, size 1x2xN
    function a = c2a(c)
        a = [...
            padarray(c{1}, [0, N_ZVAR_COEFF-numel(c{1})], 'post'); ...
            padarray(c{2}, [0, N_ZVAR_COEFF-numel(c{2})], 'post') ...
            ];    % 2 x N_ZVAR_COEFF
        a = permute(a, [3,1,2]);    % 1 x 2 x N_ZVAR_COEFF
    end
end



% Add 1 record to zVariables associated with Epoch_L.
function RctZvL = add_RCT_zvars_L(RctZvL, Epoch_L, BIAS_CURRENT_OFFSET, BIAS_CURRENT_GAIN, TRANSFER_FUNCTION_COEFFS)
    RctZvL.Epoch_L                 (end+1,1)     = Epoch_L;
    RctZvL.BIAS_CURRENT_OFFSET     (end+1,:)     = BIAS_CURRENT_OFFSET;
    RctZvL.BIAS_CURRENT_GAIN       (end+1,:)     = BIAS_CURRENT_GAIN;
    RctZvL.TRANSFER_FUNCTION_COEFFS(end+1,:,:,:) = TRANSFER_FUNCTION_COEFFS;
end



% Add 1 record to zVariables associated with Epoch_H.
function RctZvH = add_RCT_zvars_H(RctZvH, Epoch_H, V_OFFSET, E_OFFSET)
    RctZvH.Epoch_H (end+1,1) = Epoch_H;
    RctZvH.V_OFFSET(end+1,:) = V_OFFSET;
    RctZvH.E_OFFSET(end+1,:) = E_OFFSET;
end



% rctL : Struct with zVars associated with Epoch_L.
% rctH : Struct with zVars associated with Epoch_H.
function create_RCT_file(rctMasterCdfFile, destPath, rctL, rctH)
    % PROPOSAL: Assertion for matching number of records Epoch_L+data, Epoch_H+data.
    %   PROPOSAL: Read from master file which should match.
    % TODO-DECISION: Require correct MATLAB classes (via write_CDF_dataobj)?
    
    DataObj = dataobj(rctMasterCdfFile);
    
    
    DataObj.data.Epoch_L.data = rctL.Epoch_L;
    DataObj.data.Epoch_H.data = rctH.Epoch_H;
    
    DataObj.data.BIAS_CURRENT_OFFSET.data      = rctL.BIAS_CURRENT_OFFSET;         % Epoch_L
    DataObj.data.BIAS_CURRENT_GAIN.data        = rctL.BIAS_CURRENT_GAIN;           % Epoch_L
    DataObj.data.TRANSFER_FUNCTION_COEFFS.data = rctL.TRANSFER_FUNCTION_COEFFS;    % Epoch_L
    DataObj.data.E_OFFSET.data                 = rctH.E_OFFSET;   % Epoch_H
    DataObj.data.V_OFFSET.data                 = rctH.V_OFFSET;   % Epoch_H
    
    bicas.utils.write_CDF_dataobj(...
        destPath, ...
        DataObj.GlobalAttributes, ...
        DataObj.data, ...
        DataObj.VariableAttributes, ...
        DataObj.Variables);
end