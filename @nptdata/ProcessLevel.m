function [robj,data] = ProcessLevel(obj,varargin)
% Levels: The name of the highest processed level.
%               
% Include: Processes selected items instead of all
%               items found in the local directory. 
%               
% Exclude: Skips the directories or items specified in a cell array.
%               This option cannot be used together with the SelectItems
%               option. 
%               
% AnalysisLevel:  Specifies the AnalysisLevel property of OBJ.
%               Accepted values are:
%                          'Single'          Individual analysis
%                          'All'             Groups of all units (a)
%                          'Pairs'           Pairs of clusters.
%                          'AllIntra<Element>'   Groups of intra-item elements.
%                          'AllPairs'        Groups of intra-item pairs.(p)
%
% LevelObject:  Indicates that the object should be instantiated at a specific level.
% 
% DataInit: Specifies the initial value od data. 
%
% nptLevelCmd:  Specify the level Performs the following command for each
%               directory in that level, specified as a cell array, the
%               first element is the Level name, the second one is the
%               command.
% 
% DataPlusCmd: Specified if only need to plus the data of the object
%           
%
% Example 1: 
% Only select 'a1' in level Day to process.
% a = ProcessLevel(nptdata,'Levels','Days','Include','a1');
% Select both 'a2' and 'a4' in level Day to process.
% a = ProcessLevel(nptdata,'Levels','Days','Include',{'a2','a4'});
% Only process directories indicated in a cell array ndresp.SessionDirs
% a = ProcessLevel(nptdata,'Levels','Days','Include',ndresp.SessionDirs);
%
% Example 2:
% Combination data is going to be processed. Intra group pairs are preferred. 
% a = ProcessLevel(nptdata,'Levels','Days','AnalysisRelation','IntraGroup',...
%   'AnalysisLevel','Pairs');
%
% Example 3:
% Session object is created.
% a = ProcessLevel(nptdata,'Levels','Days','LevelObject','Session');
%
% Example 4:
% [nds,data] = ProcessLevel(nptdata,'Levels','Session','Include',ndcells.SessionDirs, ...
%        'nptLevelCmd',{'Cluster','pdata = adjs2gdf;'},...
%       'DataPlusCmd','data = unique([data; pdata],''Rows'');');

Args = struct('RedoValue',0,'Levels','','Include',{''},'Exclude',{''},...
    'LevelObject','','AnalysisLevel','',...
    'DataInit',[],'nptLevelCmd',{''},'DataPlusCmd','','ArgsOnly',0);
Args.flags = {'ArgsOnly'};
Args.classname = 'ProcessLevel';
[Args,varargin2] = getOptArgs(varargin,Args,'shortcuts',{'Reprocess',{'RedoValue',1}});


% if user select 'ArgsOnly', return only Args structure for an empty object
% iteration? Deduct 1 from the Args.Level after processing one level.
% if the Level is great than 1, just call the function again
% if the Level is 1, that indicates we comes to the lowest level. Just do
% what ProcessCell and ProcessTrail do.

nlevel = levelConvert('levelName',Args.Levels);
checkObjectLevel = 0;
for ii = 1:nlevel
    checkObjectLevela = strcmp(get(obj, 'ObjectLevel'), levelConvert('levelNo',ii));
    checkObjectLevel = checkObjectLevel + checkObjectLevela;
end

if (Args.ArgsOnly)
    if((nlevel-1)>1)
        if (checkObjectLevel)
            [robj, Args.childArgs] = ProcessLevel(obj, 'ArgsOnly', 'Levels', levelConvert('levelNo',nlevel-1));
            Args.childArgs{2}.classname = 'ProcessLevel';
        else
            robj = obj;
        end
    elseif((nlevel-1)==1)
        robj = obj;
        data = {'Args',Args};
        return;
    end
    robj = obj;
    data = {'Args',Args};
    return;
end

robj = obj;
data = Args.DataInit;

% SelectItem and Exclude can be specified using full paths or just the
% names for this directory so we need to add the full path for the latter
% get current directory
cwd = pwd;

DirName = getDirName(nlevel-1);
% get the pathname for the SelectItem and SkipLevelItem argument
if(~isempty(Args.Include))
    % check if Include were specified with full pathnames
    % we are going to assume that either all the directories are
    % full-paths or relative-paths so we are going to just check the
    % first entry
    if(iscell(Args.Include))
       [p,n] = nptFileParts(Args.Include{1});
       SelL = length(Args.Include);
    else
       [p,n] = nptFileParts(Args.Include);
       SelL = 1;
    end
    if(isempty(p))
        % directories were specified with relative paths so we are going
        % to add the current directory to it
%         levelnum = levelConvert('levelName',Args.SeL);
        for Includei = 1:SelL
            if(iscell(Args.Include))
                Args.Include{Includei} = [cwd filesep Args.Include{Includei}];
                if ~isdir(Args.Include{Includei})
                    Args.Include{Includei} = cwd;
                end
            else
                Args.Include = [cwd filesep Args.Include];
                if ~isdir(Args.Include)
                    Args.Include = cwd;
                end
            end
        end
    end
end

if(~isempty(Args.Exclude))
    % check if SkipLevelItem were specified with full pathnames
    % we are going to assume that either all the directories are
    % full-paths or relative-paths so we are going to just check the
    % first entry
    if(iscell(Args.Exclude))
        [p,n] = nptFileParts(Args.Exclude{1});
        SkiL = length(Args.Exclude);
    else
        [p,n] = nptFileParts(Args.Exclude);
        SkiL = 1;
    end
    if(isempty(p))
        % directories were specified with relative paths so we are going
        % to add the current directory to it
%         levelnum = levelConvert('levelName',Args.SkL);
        for Excludei = 1:SkiL
            if(iscell(Args.Exclude))
                Args.Exclude{Excludei} = [cwd filesep Args.Exclude{Excludei}];
                if ~isdir(Args.Exclude{Excludei})
                    Args.Exclude{Excludei} = cwd;
                end
            else
                Args.Exclude = [cwd filesep Args.Exclude];
                if ~isdir(Args.Exclude)
                    Args.Exclude = cwd;
                end
            end
        end
    end
end


if (~checkMarkers(obj,Args.RedoValue,Args.Levels))
%this is no marker, we should process it    
    varinNum = size(varargin, 2);
    % find the position of the argument Levels
    for k = 1:varinNum
        if(iscellstr(varargin(k)))
            findit = strcmp(varargin(k),'Levels');
            if(findit)
                position = k;
            end
        end
    end
    
    % check if object should be instantiated at the specific level
    if(isempty(Args.LevelObject))
        % LevelObject argument was not specified so check the object properties
        Args.LevelObject = get(obj,'ObjectLevel');
    end
    nLevelObject = levelConvert('levelName',Args.LevelObject);

    mark1 = 0;
    if(Args.LevelObject)
        if(levelConvert('levelName',Args.LevelObject)==nlevel)
            if(position==1)
                if(varinNum>2)
                    robj = feval(class(obj), 'auto', varargin{position+2:varinNum});
                else
                    robj = feval(class(obj), 'auto');
                end
            elseif(position==varinNum-2)
                robj = feval(class(obj), 'auto', varargin{1:varinNum-2});
            else
                robj = feval(class(obj), 'auto', varargin{1:position-1},varargin{position+2:varinNum});
            end
            mark1 = 1;
        end
    end

    if(mark1==0)
%         if(isempty(Args.nptLevelCmd) ||...
%                 (~isempty(Args.nptLevelCmd) && nlevel~=levelConvert('levelName',Args.nptLevelCmd{1})))
            if(~isempty(DirName))
                list = nptDir(DirName);
            else
                list = nptDir;
            end
            for i=1:size(list,1)
                if(list(i).isdir)
                    % get name of directory
                    item_name = list(i).name;
                    if(~strcmp(item_name,'combinations'))
                        % only continue if Include is empty or dname matches Include
                        % and Exclude is empty or dname does not match Exclude
                        % use shortcut form of or operator so we don't have to
                        % check if Exclude is empty before doing the
                        % strcmpi operation
                        go_on = 0;
                        if( (isempty(Args.Include)) && (isempty(Args.Exclude)) )
                            go_on = 1;
                        elseif(~isempty(Args.Include) && (isempty(Args.Exclude)))
                            if ~isempty(find(strmatch([pwd filesep item_name],Args.Include)))
                                go_on = 1;
                            else
                                if iscell(Args.Include)
                                    for kk = 1:length(Args.Include)
                                        if find(strmatch(Args.Include{kk},[pwd filesep item_name]))
                                            if nlevel>=nLevelObject+1
                                                go_on = 1;
                                            end
                                        end
                                    end
                                else
                                    if ~isempty(find(strmatch(Args.Include,[pwd filesep item_name])))
                                        if nlevel>=nLevelObject+1
                                            go_on = 1;
                                        end
                                    end
                                end
                            end
                        elseif(~isempty(Args.Exclude) && (isempty(Args.Include)))
                            if isempty(find(strmatch([pwd filesep item_name],Args.Exclude)))
                                go_on = 1;
                            else
                                if iscell(Args.Exclude)
                                    for kk = 1:length(Args.Exclude)
                                        if ~find(strmatch(Args.Exclude{kk},[pwd filesep item_name]))
                                            if nlevel>=nLevelObject+1
                                                go_on = 1;
                                            end
                                        end
                                    end
                                else
                                    if isempty(find(strmatch(Args.Exclude,[pwd filesep item_name])))
                                        if nlevel>=nLevelObject+1
                                            go_on = 1;
                                        end
                                    end
                                end
                            end
                            
                        end

                        if(go_on)
                            fprintf(['Processing  Level %i  ' levelConvert('levelNo',nlevel-1) ' ' item_name '\n'], nlevel-1);
                            cd (item_name)
                            % check the present level, to decide if we need to
                            % continue to call ProcessLevel
%                             if(isempty(Args.nptLevelCmd) ||...
%                                     (~isempty(Args.nptLevelCmd) && nlevel-1~=levelConvert('levelName',Args.nptLevelCmd{1})))
                                if isempty(Args.AnalysisLevel)
                                    if nlevel > nLevelObject+1
                                        cmdstr = 'Level';
                                    elseif nlevel == nLevelObject+1
                                        cmdstr = 'feval';
                                    end
                                else%if(isempty(Args.AnalysisLevel))
                                    if strcmp(Args.AnalysisLevel,'Single')
                                        if nlevel > nLevelObject+1
                                            cmdstr = 'Level';
                                        elseif nlevel == nLevelObject+1
                                            cmdstr = 'feval';
                                        end
                                    else
                                        if nlevel == nLevelObject+3
                                            cmdstr = 'Combination';
                                        elseif nlevel > nLevelObject+1
                                            cmdstr = 'Level';
                                        elseif nlevel == nLevelObject+1
                                            cmdstr = 'feval';
                                        end
                                    end
                                end%(isempty(Args.AnalysisLevel))
%                             elseif (~isempty(Args.nptLevelCmd) && nlevel-1==levelConvert('levelName',Args.nptLevelCmd{1}))
%                                 eval(Args.nptLevelCmd{2});
%                                 cmdstr = 'other';
%                             end %if(isempty(Args.nptLevelCmd))
                        
                            
                                switch cmdstr
                                    case 'Level'
                                        if(position==1)
                                            if(varinNum>2)
                                                [p,pdata] = ProcessLevel(eval(class(obj)),'Levels',levelConvert('levelNo',nlevel-1),varargin{position+2:varinNum});
                                            else
                                                [p,pdata] = ProcessLevel(eval(class(obj)),'Levels',levelConvert('levelNo',nlevel-1));
                                            end
                                        elseif(position==varinNum-2)
                                            [p,pdata] = ProcessLevel(eval(class(obj)),'Levels',levelConvert('levelNo',nlevel-1),varargin{1:varinNum-2});
                                        else
                                            [p,pdata] = ProcessLevel(eval(class(obj)),'Levels',levelConvert('levelNo',nlevel-1),varargin{1:position-1},varargin{position+2:varinNum});
                                        end
                                        robj = plus(robj,p,varargin2{:});
                                        if(~isempty(Args.DataPlusCmd))
                                            eval(Args.DataPlusCmd);
                                        end
                                        cd ..
                                    case 'Combination'
                                        if(position==1)
                                            if(varinNum>2)
                                                [p,pdata] = ProcessCombination(obj,'Levels',levelConvert('levelNo',nlevel-1),varargin{position+2:varinNum});
                                            else
                                                [p,pdata] = ProcessCombination(obj,'Levels',levelConvert('levelNo',nlevel-1));
                                            end
                                        elseif(position==varinNum-2)
                                            [p,pdata] = ProcessCombination(obj,'Levels',levelConvert('levelNo',nlevel-1),varargin{1:varinNum-2});
                                        else
                                            [p,pdata] = ProcessCombination(obj,'Levels',levelConvert('levelNo',nlevel-1),varargin{1:position-1},varargin{position+2:varinNum});
                                        end
                                        robj = plus(robj,p,varargin2{:});
                                        if(~isempty(Args.DataPlusCmd))
                                            eval(Args.DataPlusCmd);
                                        end
                                        cd ..
                                    case 'feval'
                                        if(isempty(Args.nptLevelCmd))
                                            if(position==1)
                                                if(varinNum>2)
                                                    p = feval(class(obj), 'auto', varargin{:});
                                                else
                                                    p = feval(class(obj), 'auto');
                                                end
                                            elseif(position==varinNum-2)
                                                p = feval(class(obj), 'auto', varargin{1:varinNum-2});
                                            else
                                                p = feval(class(obj), 'auto', varargin{1:position-1},varargin{position+2:varinNum});
                                            end
                                            robj = plus(robj,p,varargin2{:});
                                        else
                                            eval(Args.nptLevelCmd{2});
                                        end
                                        if(~isempty(Args.DataPlusCmd))
                                            eval(Args.DataPlusCmd);
                                        end
                                        cd ..
%                                     case 'other'
%                                         if(~isempty(Args.DataPlusCmd))
%                                             eval(Args.DataPlusCmd);
%                                         end
                                end
                            
                        end % if(go_on)
                    end
                end %if(list(i).isdir)
            end %for i=1:size(list,1)
%         elseif (~isempty(Args.nptLevelCmd) && nlevel==levelConvert('levelName',Args.nptLevelCmd{1})) 
%             eval(Args.nptLevelCmd{2});
%         end %if(isempty(Args.nptLevelCmd))
    end %if(mark1==0)
    % create marker if necessary
    createProcessedMarker(obj,Args.Levels);
end