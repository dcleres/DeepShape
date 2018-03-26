function [srsOut,flipMsg]=reorient(srs,outOrient,srsOrient)
%REORIENT Generate an different orthogonal orientation of specified image volume(s).
%
%  Transform image volume(s) into a requested orthogonal orientation.  This
%  includes both permutation and flips in x, y, and z.
%
%  srsOut=reorient(srs,outOrient);
%  srsOut=reorient(srs,outOrient,srsOrient);
%  [srsOut,flipMsg]=reorient(srs,outOrient);
%  [srsOut,flipMsg]=reorient(srs,outOrient,srsOrient);
%
%  Inputs:
%    srs is the image volume(s) as read by READMR.
%      Must have at least 3 or more dimensions ordered x,y,z.
%      This may also be a simple N-D numeric volume if srsOrient is specified.
%    outOrient is the desired output orientation (default lpi)
%      Three character indicating direction of increasing values
%      in each of three dimensions.
%      e.g. lpi ->  X: R to L, Y: A to P, Z: S to I (Standard Axial S to I)
%    srsOrient is the orientation of srs (optional)
%      Three character string like outOrient. This function attempts to
%      determine srsOrient using getorientation.  If getorientation is
%      unable to determine orientation, srsOrient must be specified.  If
%      srsOrient specified, it must match the value returned by
%      getorientation.
%
%  Output:
%    srsOut is the specified volume(s) in the requested orientation.
%    flipMsg is a message indicating which dimensions were flipped. (optional)
%      If this output argument is not requested, the string will display in
%      the command window.
%
% See Also: READMR

% CVS ID and authorship of this code
% CVSId = '$Id: reorient.m,v 1.11 2005/02/03 16:58:42 michelich Exp $';
% CVSRevision = '$Revision: 1.11 $';
% CVSDate = '$Date: 2005/02/03 16:58:42 $';
% CVSRCSFile = '$RCSfile: reorient.m,v $';

% Check arguments and setup defaults
error(nargchk(1,3,nargin));
if nargin < 2 | isempty(outOrient), outOrient='lpi'; end
if nargin < 3, srsOrient=''; end

% Copy input to output
if isstruct(srs)
  % srs contains meta-info
  % Check for fields we will use (if srsOrient was not specified)
  if ~isfield(srs,'info') | ~isfield(srs.info,'dimensions') | ...
      ~isfield(srs,'data')
    error('Invalid srs: Does not have srs.info.dimensions or srs.data fields!');
  end
  srsOut=srs; % Replace srsOut.data before returning from function.
  srsOutData=srs.data;
else
  % srs is simple numeric array
  srsOut='';
  srsOutData=srs;
  if isempty(srsOrient),
    error('Must specify a orientation of input if it is a simple numeric array!');
  end
end

% Min of 3 dimensions
if ndims(srsOutData) < 3
  error('Input series must be have 3 or more dimensions!');
end

% Generate a vector of the dimensions greater than 3
if ndims(srsOutData) == 3
  extraDims = [];
else
  extraDims = 4:ndims(srsOutData);
end

% Try to determine orientation of volume passed.
% TODO: Think about handling case when cannot determine orientation but have srs.info...
currOrient='';
if ~isempty(srsOut)  % Don't even try if only a simple numeric array was specified
  try
    currOrient=getorientation(srs);
  catch
    % If user didn't tell us the orientation, rethrow error.
    if isempty(srsOrient)
      emsg=lasterr; 
      if isempty(emsg), error('Unknown error occured using getorientation!'); end
      error(emsg);
    end
    currOrient='';
  end
end

% Make sure that the calculated and specified orientations match
if ~isempty(srsOrient) & ~isempty(currOrient) & ~strcmp(currOrient,srsOrient)
  error('Orientation of image indicated in the info fields does not match srsOrient!');
end

% Use the input orientation if it was specified 
if ~isempty(srsOrient), currOrient=srsOrient; end

% --- Permute the data and info.dimensions ---
curr2outMapping=local_calcRASpermute(currOrient,outOrient);
srsOutData=permute(srsOutData,[curr2outMapping extraDims]);
if ~isempty(srsOut)
  dimnames = {srsOut.info.dimensions(1:3).type};
  properdimnames = {'x','y','z'};
  if ~all(strcmp(dimnames, properdimnames))
    error('First dimensions in input struct are not ordered "x", "y", "z"!');
  end
  srsOut.info.dimensions=srsOut.info.dimensions([curr2outMapping extraDims]);
  [srsOut.info.dimensions(1:3).type] = deal(properdimnames{:});
end

% --- Flip dimensions as necessary ---
flipflag= (outOrient ~= currOrient(curr2outMapping));
if any(flipflag)
  % Calculate strings identifying each dimension of the input
  ras2outMapping=local_calcRASpermute('ras',outOrient);
  flipString = {'Right-Left','Anterior-Posterior','Superior-Inferior'};
  flipString = flipString(ras2outMapping);
  flipMsg = 'Caution! Flipping images: ';

  % Flip as necessary
  if ~isempty(srsOut)
    % update info
    % Flip datapoints
    for n=find(flipflag)
      dim = srsOut.info.dimensions(n);
      if length(dim.datapoints)==1 & isnan(dim.datapoints{1})
        dim.datapoints = dim.datapoints(length(dim.datapoints):-1:1);
      end
      srsOut.info.dimensions(n) = dim;
    end
    % Flip origin, spacing, and direction
    originvec = [srsOut.info.dimensions(1:3).origin];
    spacingvec = [srsOut.info.dimensions(1:3).spacing];
    sizevec = [srsOut.info.dimensions(1:3).size];
    directionvec = reshape([srsOut.info.dimensions(1:3).direction], 3, 3);
    if ~any(isnan(originvec)) & ~any(isnan(directionvec(:)))
      for n=find(flipflag)
        originvec = originvec + ((sizevec(n)-1) * spacingvec(n) * rot90(directionvec(:,n)));
      end
      for n=find(flipflag)
        directionvec(:,n) = -1 * directionvec(:,n);
      end
    elseif ~all(isnan(originvec)) | ~all(isnan(directionvec(:)))
      error('Some, but not all, of origin or direction fields are NaN!');
    end
    srsOut.info.dimensions(1).origin = originvec(1);
    srsOut.info.dimensions(2).origin = originvec(2);
    srsOut.info.dimensions(3).origin = originvec(3);
    srsOut.info.dimensions(1).direction = rot90(directionvec(:,1));
    srsOut.info.dimensions(2).direction = rot90(directionvec(:,2));
    srsOut.info.dimensions(3).direction = rot90(directionvec(:,3));
  end
  for n=find(flipflag)
    % Flip Data
    srsOutData=flipdim(srsOutData,n);
  
    % Update message to user.
    flipMsg = [flipMsg flipString{n} ', '];
  end
  flipMsg(end-1:end)='';  % Remove final ', '
  
  % Display flip messages if user is not keeping them in an output array.
  if nargout < 2, disp(flipMsg); end
end

% Construct output array
if ~isempty(srsOut)
  srsOut.data=srsOutData;
else
  srsOut=srsOutData;
end

% % Debug feedback
% disp(sprintf('Current Orientation: %s',currOrient));
% disp(sprintf('Output Orientation: %s',outOrient));
% disp(sprintf('Mapping of input to output dimensions:%s',sprintf(' %d',curr2outMapping)));
% 
% % Code to test local_calcRASpermute.
% tests={'ras','rsa','ars','asr','sar','sra'};
% for n=1:length(tests)
%   for m=1:length(tests)
%     if ~strcmp(tests{n}(local_calcRASpermute(tests{n},tests{m})),tests{m})
%       disp(sprintf('Failed test: %s to %s',tests{n},tests{m}));
%     end  
%   end
% end

% --- local_calcRASpermute ---
function in2outMapping=local_calcRASpermute(inOrient,outOrient)
% local_calcRASpermute - Calculate permutation between two RAS flags
%
% Calculate the perumuation necessary to transform from the input
% RAS flag to the output RAS flag
%
%  in2outMapping=local_calcRASpermute(inOrient,outOrient);
%    inOrient is the original orientation ras flag
%    outOrient is the desired orientation ras flag
%    in2outMapping is a three element vector with the permuation from
%      inOrient to outOrient.
%   
%    inOrient and outOrient must be three character strings indicating
%    direction of increasing values in each of three dimensions.
%       e.g. lpi ->  X: R to L, Y: A to P, Z: S to I (Standard Axial S to I)
%

% Get rid of direction on orientations.
inOrient(find(inOrient=='l'))='r';
inOrient(find(inOrient=='p'))='a';
inOrient(find(inOrient=='i'))='s';
outOrient(find(outOrient=='l'))='r';
outOrient(find(outOrient=='p'))='a';
outOrient(find(outOrient=='i'))='s';

% Check that these are valid RAS flags
if ~strcmp(sort(inOrient),'ars'), error('inOrient is not a valid RAS flag!'); end
if ~strcmp(sort(outOrient),'ars'), error('inOrient is not a valid RAS flag!'); end

% Determine mapping of dimension order from input to output
for n=1:3
  % TODO: More efficient method to handle this???
  in2outMapping(n) = find(outOrient(n)==inOrient);
end

% Modification History:
%
% $Log: reorient.m,v $
% Revision 1.11  2005/02/03 16:58:42  michelich
% Changes based on M-lint:
% Make unused CVS variables comments for increased efficiency.
% Remove unnecessary semicolon after function declarations.
% Remove unnecessary commas after try, catch, and else statements.
%
% Revision 1.10  2003/10/22 15:54:38  gadde
% Make some CVS info accessible through variables
%
% Revision 1.9  2003/09/25 20:54:48  gadde
% Make sure datapoints is a cell array.
%
% Revision 1.8  2003/06/30 16:54:31  michelich
% Updated for readmr name change.
%
% Revision 1.7  2003/06/06 13:53:27  michelich
% Update/fix handling of datapoints field when flipping.
%
% Revision 1.6  2003/04/11 14:17:44  gadde
% Fix dimension types in reorder to be 'x', 'y', 'z'.
%
% Revision 1.5  2003/04/08 15:34:00  michelich
% Require srsOrient if input is a simple numeric array.
%
% Revision 1.4  2003/04/07 18:45:09  gadde
% Fix errant dot and remove unnecessary squeezes
%
% Revision 1.3  2003/04/07 18:10:09  gadde
% Update info fields (did we get them all?)
%
% Revision 1.2  2003/04/05 05:43:06  michelich
% Fixed flipdim bugs.
% Added handling of "raw" numeric arrays.
%
% Revision 1.1  2003/04/04 23:41:34  michelich
% Original Version.
%
