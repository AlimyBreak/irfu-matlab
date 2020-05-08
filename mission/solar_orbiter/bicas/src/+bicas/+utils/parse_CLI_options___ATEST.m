%
% Automatic test code for bicas.utils.parse_CLI_options.
%
function parse_CLI_options___ATEST


Ocm1 = containers.Map(...
        {'a', 'b', 'c'}, ...
        {...
            struct('optionHeaderRegexp', '-a', 'occurrenceRequirement', '0-1',   'nValues', 0), ...
            struct('optionHeaderRegexp', '-b', 'occurrenceRequirement', '1',     'nValues', 1), ...
            struct('optionHeaderRegexp', '-c', 'occurrenceRequirement', '0-inf', 'nValues', 2)...
        });

Ocm2 = containers.Map(...
        {'--', '=='}, ...
        {...
            struct('optionHeaderRegexp', '--.*', 'occurrenceRequirement', '0-1',   'nValues', 0), ...
            struct('optionHeaderRegexp', '==.*', 'occurrenceRequirement', '0-inf', 'nValues', 0) ...
        });
    
Ocm3 = containers.Map(...
        {'all', 'log', 'set'}, ...
        {...
            struct('optionHeaderRegexp', '--.*',    'occurrenceRequirement', '0-inf', 'nValues', 1, 'interprPriority', -1), ...
            struct('optionHeaderRegexp', '--log',   'occurrenceRequirement', '1',     'nValues', 1), ...
            struct('optionHeaderRegexp', '--set.*', 'occurrenceRequirement', '0-inf', 'nValues', 1) ...
        });

EOO = oo(cell(0,1), cell(0,1), cell(0,1));

tl = {};
tl{end+1} = new_test(Ocm1, '-a',                   'MException');
tl{end+1} = new_test(Ocm1, '-b 123',               {'a', 'b', 'c'}, {EOO,              oo(1, '-b', {'123'}),   EOO});
tl{end+1} = new_test(Ocm1, '-a -b 123',            {'a', 'b', 'c'}, {oo(1, '-a', {}),  oo(2, '-b', {'123'}),   EOO});
tl{end+1} = new_test(Ocm1, '-a -b 123 -c 8 9',     {'a', 'b', 'c'}, {oo(1, '-a', {}),  oo(2, '-b', {'123'}),   oo(4, '-c', {'8', '9'})});


tl{end+1} = new_test(Ocm1, '-c 6 7 -a -b 123 -c 8 9', {'a', 'b', 'c'}, {...
    oo(4, '-a', {}), ...
    oo(5, '-b', {'123'}), ...
    [oo(1, '-c', {'6', '7'}), oo(7, '-c', {'8', '9'})]});   % Test multiple occurrences of the same option.
tl{end+1} = new_test(Ocm1, '-c 6 7 -b 123 -c 8 9',    {'a', 'b', 'c'}, {...
    EOO, ...
    oo(4, '-b', {'123'}), ...
    [oo(1, '-c', {'6', '7'}), oo(6, '-c', {'8', '9'})]});   % Test multiple occurrences of the same option.

tl{end+1} = new_test(Ocm2, '--ASD',                        {'--', '=='}, {oo(1, '--ASD', {}), EOO});
tl{end+1} = new_test(Ocm2, '==ASD ==a --abc',              {'--', '=='}, {oo(3, '--abc', {}), [oo(1, '==ASD', {}), oo(2, '==a', {})]});



tl{end+1} = new_test(Ocm3, '--input1 i1 --output1 o1 --log logfile',               {'all', 'log', 'set'}, {...
    [oo(1, '--input1',  {'i1'}), ...
    oo(3, '--output1', {'o1'})], ...
    oo(5, '--log',     {'logfile'}), ...
    EOO});

tl{end+1} = new_test(Ocm3, '--input1 i1 --output1 o1 --log logfile --setDEBUG ON', {'all', 'log', 'set'}, {...
    [oo(1, '--input1', {'i1'}), ...
    oo(3, '--output1', {'o1'})], ...
    oo(5, '--log',     {'logfile'}), ...
    oo(7, '--setDEBUG', {'ON'})});



EJ_library.atest.run_tests(tl)

end



function NewTest = new_test(OptionsConfigMap, inputStr, outputMapKeys, outputMapValues)

input     = {strsplit(inputStr), OptionsConfigMap};
if     (nargin == 3) && ischar(outputMapKeys)
    expOutput = outputMapKeys;
elseif (nargin == 4) && iscell(outputMapKeys)
    expOutput = {containers.Map(outputMapKeys, outputMapValues)};
end

NewTest = EJ_library.atest.CompareFuncResult(@bicas.utils.parse_CLI_options, input, expOutput);
end


% function NewTest = new_test2(OptionsConfigMap, inputStr, outputMapKeys, outputMapValues)
% 
% input     = {strsplit(inputStr), OptionsConfigMap};
% expOutput = {containers.Map(outputMapKeys, outputMapValues)};
% 
% NewTest = EJ_library.atest.CompareFuncResult(@bicas.utils.parse_CLI_options, input, expOutput);
% end



function OptionOccurrence = oo(iOptionHeaderCliArgument, optionHeader, optionValues)
    assert(iscell(optionValues))
    if isempty(optionValues)
        optionValues = cell(0,1);
    end
    optionValues = optionValues(:);   % Force column vector.
    
    OptionOccurrence = struct(...
        'iOptionHeaderCliArgument', iOptionHeaderCliArgument, ...
        'optionHeader', optionHeader, ...
        'optionValues', {optionValues});
end