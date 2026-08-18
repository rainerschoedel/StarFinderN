; $Id: remove_coincident.pro, v 1.0 Aug 1999 e.d. $
;
;+
; NAME:
;	REMOVE_COINCIDENT
;
; PURPOSE:
;	Given a set of points on a plane, remove multiple occurences of
;	coincident points.
;
; CATEGORY:
;	Array manipulation.
;
; CALLING SEQUENCE:
;	REMOVE_COINCIDENT, X, Y, X_distinct, Y_distinct
;
; INPUTS:
;	X, Y:	X- and y- coordinates of points
;
; OUTPUTS:
;	X_distinct, Y_distinct:	Coordinates of distinct points. The same
;		variables used on input may be used for the output
;
; RESTRICTIONS:
;	Apply only to points on a plane.
;
; PROCEDURE:
;	Recursive procedure: given a subset made of N-1 distinct points,
;	consider the next point in the original list and append it if
;	distinct from the first N-1.
;
; MODIFICATION HISTORY:
; 	Written by:	Emiliano Diolaiti, August 1999.



; ADD_POINTS: auxiliary procedure called by REMOVE_COINCIDENT.

PRO add_points, x, y, x_out, y_out, n

	on_error, 2
	if  n eq 0  then begin
	   ; base case
	   x_out = x[n]  &  y_out = y[n]
	endif else begin
	   ; induction case
	   add_points, x, y, x_out, y_out, n - 1
	   if  min(distance(x[n], y[n], x_out, y_out)) ne 0  then begin
	      x_out = append_elements(x_out, x[n])
	      y_out = append_elements(y_out, y[n])
	   endif
	endelse
	return
end


PRO remove_coincident, x, y, x_distinct, y_distinct

	on_error, 2
	npt = n_elements(x)
	if  npt eq 0 or n_elements(y) ne npt  then  return
	add_points, x, y, x_out, y_out, npt - 1
	x_distinct = x_out  &  y_distinct = y_out
	return
end
