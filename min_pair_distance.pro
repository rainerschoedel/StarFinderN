; $Id: min_pair_distance.pro, v 1.0  $
;+
; NAME:
;	MIN_PAIR_DISTANCE
;
; PURPOSE:
;	Compute the minimum euclidean distance among all pairs of a set
;	of points on a plane. This is the minimum of the full pairwise
;	distance matrix computed by RECIPROCAL_DISTANCE, obtained without
;	allocating the whole matrix and with early exit as soon as a
;	pair closer than a given threshold is found.
;
; CATEGORY:
;	Mathematics.
;
; CALLING SEQUENCE:
;	Result = MIN_PAIR_DISTANCE(X, Y, THRESHOLD = threshold)
;
; INPUTS:
;	X, Y:	Coordinates of N points
;
; KEYWORD PARAMETERS:
;	THRESHOLD:	Optional scalar. If supplied, the routine returns
;			THRESHOLD as soon as a pair with distance strictly
;			less than THRESHOLD is found (early exit). The
;			returned value is then < THRESHOLD, so the test
;			"result ge THRESHOLD" keeps the same semantics as
;			"min(reciprocal_distance(x,y)) ge THRESHOLD".
;
; OUTPUTS:
;	Result:	Minimum pairwise distance. Returns 0 if N = 1 (single
;		point, no pairs). Returns a negative scalar if X and Y have
;		different sizes.
;
; MODIFICATION HISTORY:
;	Written for StarFinderN as a low-risk replacement of
;	min(reciprocal_distance(x,y)) in STARFINDER_CHECK.
;-

FUNCTION min_pair_distance, x, y, THRESHOLD = threshold

	on_error, 2
	n = n_elements(x)
	if  n_elements(y) ne n  then  return, -1
	if  n le 1  then  return, 0
	if  n_elements(threshold) eq 0  then  threshold = -1
	dmin = !values.f_max
	for  i = 0L, n - 2  do begin
	   d = distance(x[i], y[i], x[i+1:n-1], y[i+1:n-1])
	   di = min(d)
	   if  di lt dmin  then  dmin = di
	   if  dmin lt threshold  then  return, dmin
	endfor
	return, dmin
end
