; $Id: all_max.pro, v 1.0 Aug 1999 e.d. $
;
;+
; NAME:
;	ALL_MAX
;
; PURPOSE:
;	Find relative maxima in a 2D array.
;	A given pixel is considered a relative maximum if it is brighter
;	than its 8-neighbors or 4-neighbors.
;
; CATEGORY:
;	Signal processing.
;
; CALLING SEQUENCE:
;	ALL_MAX, Array, X, Y, N
;
; INPUTS:
;	Array:	2D array to be searched
;
; KEYWORD PARAMETERS:
;	FOUR:	Set this keyword to identify relative maxima as pixels
;		brighter than their 4-neighbors. The default is to use
;		8-neighbors.
;
; OUTPUTS:
;	X, Y:	Coordinates of detected maxima
;
;	N:	Number of detected maxima
;
; MODIFICATION HISTORY:
; 	Written by:	Emiliano Diolaiti, August 1999.
;-

PRO all_max, array, x, y, n, FOUR = four

	on_error, 2
	siz = size52(array, /DIM)  &  sx = siz[0]  &  sy = siz[1]
	ext_array = extend_array(array, sx + 2, sy + 2)
	m = make_array(sx + 2, sy + 2, /BYTE, VALUE = 1B)
	for  dx = -1, 1  do  for  dy = -1, 1  do begin
	   if  keyword_set(four)  then $
	      check = abs(dx) ne abs(dy)  else $	; 4-neighbors
	      check = dx ne 0 or dy ne 0			; 8-neighbors
	   if  check  then $
	      m = temporary(m) and ext_array gt shift(ext_array, dx, dy)
    endfor
    w = where(m[1:sx,1:sy] eq 1, n)
	if  n ne 0  then  subs_to_coord, w, sx, x, y
	if  n eq 1  then begin
	   x = x[0]  &  y = y[0]
	endif
	return
end
