%
% Automated test code for interpret_config_file.
%
%
% Author: Erik P G Johansson, IRF-U, Uppsala, Sweden
% First created 2018-01-25
%
function regexp_str_parts___ATEST()

    KEY_ANY_VALUE_REGEXP_LIST            = {'[a-z]+', '=', '.*'};   % Not whitespace before or after =.
    KEY_QUOTED_VALUE_REGEXP_LIST         = {'[a-zA-Z0-9._]+', ' *= *', '"', '[^"]*', '"', ' *'};    % Require quoted value.
    KEY_QUOTED_VALUE_COMMENT_REGEXP_LIST = {'[a-zA-Z0-9._]+', ' *= *', '"', '[^"]*', '"', ' *', '(#.*)?'};

    ES = char(zeros(1,0));    % Emty string, size 1x0.

    new_test   = @(inputs, outputs)        (EJ_library.atest.CompareFuncResult(@EJ_library.utils.regexp_str_parts, inputs, outputs));
    new_test_A = @(arg1, arg2, outputs) (new_test({arg1, arg2, 'assert match'    }, outputs));   % A = Assert match
    new_test_P = @(arg1, arg2, outputs) (new_test({arg1, arg2, 'permit non-match'}, outputs));   % P = Permit non-match
    
    
    
    tl = {};

    tl{end+1} = new_test_A('',     {''},       {{''}',    ES});

    tl{end+1} = new_test_A('abc', {'a', 'b', 'c'}, {{'a' 'b' 'c'}', ES});
    tl{end+1} = new_test_P('abc', {'a', 'b', 'c'}, {{'a' 'b' 'c'}', ES});
    
    tl{end+1} = new_test_A('ab', {'a', 'b', 'c'}, 'MException');
    tl{end+1} = new_test_P('ab', {'a', 'b', 'c'}, {{'a', 'b'}', ES});
    
    tl{end+1} = new_test_A('ac', {'a', 'b', 'c'}, 'MException');
    tl{end+1} = new_test_A('a',  {'a', 'b', 'c'}, 'MException');
    tl{end+1} = new_test_A('ac', {'a', 'b'     }, 'MException');
    
    
    tl{end+1} = new_test_A('word',  {'[a-z]+'}, {{'word'}', ES});
    tl{end+1} = new_test_A('key = value', KEY_QUOTED_VALUE_REGEXP_LIST, 'MException');
    
    tl{end+1} = new_test_A('key=value',                     KEY_ANY_VALUE_REGEXP_LIST,            {{'key', '=',         'value'            }', ES});
    tl{end+1} = new_test_A('key = "value"',                 KEY_QUOTED_VALUE_REGEXP_LIST,         {{'key', ' = ', '"',  'value', '"', ''   }', ES});
    tl{end+1} = new_test_A('key=   "value"   ',             KEY_QUOTED_VALUE_REGEXP_LIST,         {{'key', '=   ', '"', 'value', '"', '   '}', ES});
    tl{end+1} = new_test_A('key_name.subset   =" .-/ "   ', KEY_QUOTED_VALUE_REGEXP_LIST,         {{'key_name.subset', '   =', '"', ' .-/ ', '"', '   '}', ES});
    tl{end+1} = new_test_A('key = "value"',                 KEY_QUOTED_VALUE_COMMENT_REGEXP_LIST, {{'key', ' = ', '"', 'value', '"', '', ''}', ES});
    tl{end+1} = new_test_A('key = "value"   # Comment',     KEY_QUOTED_VALUE_COMMENT_REGEXP_LIST, {{'key', ' = ', '"', 'value', '"', '   ', '# Comment'}', ES});
    
    

    EJ_library.atest.run_tests(tl)    
end