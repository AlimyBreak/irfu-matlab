%
% Split a string into consecutive parts, each one corresponding to a regexp match.
%
% The primary purpose of this function is to make it easy to parse a string syntax.
%
% ALGORITHM
% =========
% The algorithm will try to match the beginning of str to the first regexp, then continue to match the remainder of the
% string for each successive regexp.
% --
% NOTE: A regexp that does match an empty string (e.g. 'a*'), may return an empty substring. This is natural in this
% application, but is maybe not default regexp behaviour.
% --
% NOTE: The algorithm does not work for "all" applications. Ex: Matching with restrictive regexp (one or several) at the
% end of string while simultaneously having regexp that permits ~arbitrary string in the beginning/middle. Arbitrary
% string will match until the end (maximal munch), preventing matching the ending regular expressions.
% --
% NOTE: Assertion on matching all of string, i.e. exception if can not match entire string.
%
%
% ARGUMENTS
% =========
% str            : String
% regexpList     : Cell array of strings, each one containing a regexp. "^" at the beginning of a regexp will be ignored.
%                  NOTE: The sequence of regexes must match every single character in str.
% nonMatchPolicy : String constant determining what happens in the event of a non-perfect match (including no match).
%                  'assert match' or 'permit non-match'
%
%
% RETURN VALUE
% ============
% subStrList     : Cell array of strings, each being a match for the corresponding string in regexpList.
% remainingStr   : The remainder of argument str that was not matched.
% perfectMatch   : Logical.
%
%
% Author: Erik P G Johansson, IRF Uppsala, Sweden
% First created 2018-01-25.
%
function [subStrList, remainingStr, perfectMatch] = regexp_str_parts(str, regexpList, nonMatchPolicy)
    % PROPOSAL: Better function name.
    %
    % PROPOSAL: Somehow improve to prevent failing for regexps matching ~arbitrary strings before other regexp(s).
    %   Ex: Matching SO dataset filename. Can not match "-CDAG" or ".cdf".
    %   PROPOSAL: Option to search backwards (only).
    %       TODO-DECISION: How represent partial match (only some substrings)?
    %   PROPOSAL: Simultaneously searching from both beginning and end.
    %   PROPOSAL: Associate order of matching with each regexp. Must go from edges toward the middle (a regexp must be
    %       applied to a string that is adjacent to at least one already matched substring.
    %       CON: Still does not work for regexp surrounded by two ~arbitrary strings.
    %           CON: Impossible problem to solve, even in principle(?).
    %               PROPOSAL: Allow to search for matching substrings inside interior substring (substring not bounded by
    %                         already made matches).
    %                   NOTE: Not exact solution, but probably works practically for most applications.
    %                   CON: Better done manually or by another function that uses this function. This is outside of
    %                        this function's natural scope.
    %   PROPOSAL: Three functions
    %       [subStrList, remainingStr] = regexp_str_parts(str, regexpList, searchDirection, nonMatchPolicy)
    %           Only search either forward or backward (argument).
    %       [subStrList, remainingStr] = regexp_str_parts2(str, regexpList, searchPriorities, nonMatchPolicy)
    %           Uses regexp_str_parts. Each regexp is associated with a number. Search forward or backward from the
    %           edges depending on searchPriorities. searchPriorities = one integer per regexp. Can not be arbitrary;
    %           must increase toward the middle.
    %
    % PROPOSAL: Do not throw error on not matching, but return special value.
    %   PROPOSAL: Return empty.
    %   PROPOSAL: Have policy argument determine whether exception or special return value.
    %       PROPOSAL: 'assert match', 'permit no match'/'no assert match'
    %           NOTE: Easy for caller to assert: assert(~isempty(subStrList)).
    %   PROPOSAL: Permit returning partial results and letting the caller where it failed.
    %
    % PROPOSAL: Somehow specify whether to ignore case or not, for every regexp separately(!).
    %
    % PROPOSAL: Additional easy-to-use return value for verifying perfect match.
    %   PROBLEM: How make it fit with assertionPolicy? Should not be in the way with 'assert match'.
    %       PROPOSAL: [subStrList, remainingStr, perfectMatch]
    %           PRO: Backward-compatible.
    %       PROPOSAL: [subStrList, perfectMatch, remainingStr]
    %           PRO: Does not need to store remainingStr, even if only wants perfectMatch.
    %
    % PROPOSAL: Implement using EJ_library.utils.read_req_token.
    %   CON: Can not use backwards.
    %
    % NOTE: Could almost(?) use function to implement equivalent functionality of regular expressions with
    % (positive) lookbehind+lookahead (other function).
    %   PROPOSAL: Implement (other function) that uses regexp with effectively (positive) lookbehind+lookahead to search through strings:
    %       (1) Join three regexps (lookbehind, search pattern, lookahead) into one regexp, and search for matches.
    %       (2) Use regexp_str_parts to find out which parts correspond to which of the three regexps.
    %       (3) Return only the match for the search pattern regexp.
    %       TODO-NI: Rigorous? Are there no cases it can not handle?!
    %       TODO-NI: Can modify to use negative lookbehind+lookahead?
    
    
    %==================================
    % Interpret, verify nonMatchPolicy
    %==================================
    switch(nonMatchPolicy)
        case 'assert match'
            assertMatch = true;
            
        case 'permit non-match'
            assertMatch = false;
            
        otherwise
            % ASSERTION
            error('Illegal argument nonMatchPolicy="%s"', nonMatchPolicy)
    end
    clear nonMatchPolicy
    
    
    
    %===========
    % ALGORITHM
    %===========
    subStrList = cell(0, 1);
    remainingStr = str;
    for i = 1:numel(regexpList)
        % IMPLEMENTATION NOTE: Option "emptystring" is important. Can otherwise not distinguish between (1) no match, or
        % (2) matching empty string, e.g. for regexp ' *'. This important e.g. for matching unimportant whitespace in a
        % syntax.
        subStr = regexp(remainingStr, ['^', regexpList{i}], 'match', 'emptymatch');
        if isempty(subStr)
            % NOTE: isempty() refers to cell array, not string. subStr should be cell array if match, even empty string match.
            
            if assertMatch
                % ASSERTION
                error('regexp_str_parts:Assertion', 'Could not match regular expression "%s" to the beginning of the remainder of the string, "%s".', regexpList{i}, remainingStr)
            else
                % NOTE: subStrList partially completed.
                perfectMatch = false;
                return
            end
        end
        subStr = subStr{1};
        
        remainingStr = remainingStr(numel(subStr)+1:end);
        subStrList{i,1} = subStr;   % Add to list of matches.
    end
    
    
    
    %=======================================
    % Check if algorithm matched everything
    %=======================================
    if ~isempty(remainingStr)
        % CASE: subStrList "completed" (one string for every regexp), but remainingStr is not empty.
        if assertMatch
            % ASSERTION
            error('regexp_str_parts:Assertion', 'Only the beginning of argument str="%s" matches the submitted regular expressions.', str)
        else
            perfectMatch = false;
            return
            % Do nothing
        end
    end
    
    perfectMatch = true;
end

