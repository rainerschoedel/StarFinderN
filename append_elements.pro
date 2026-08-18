; $Id: append_elements.pro, v 1.0 Aug 1999 e.d. $
;
;+
; NAME:
;	APPEND_ELEMENTS
;
; PURPOSE:
;	Append new elements to 1D vector.
;
; CATEGORY:
;	Array manipulation.
;
; CALLING SEQUENCE:
;	Result = APPEND_ELEMENTS(V, Elements)
;
; INPUTS:
;	Vector:	input vector
;
;	Elements:	Scalar or vector, representing element(s) to be appended
;
; OUTPUTS:
;	Results:	Input array with appended elements
;
; RESTRICTIONS:
;	Apply only to 1D vectors or scalars.
;
; MODIFICATION HISTORY:
; 	Written by:	Emiliano Diolaiti, August 1999.
;-

FUNCTION append_elements, v, elements

	on_error, 2
	n = n_elements(v)
	if  n eq 0  then  return, elements
	if  size52(v, /N_DIM) gt 1  or $
		size52(elements, /N_DIM) gt 1  then  return, elements
	v_and_el = make_array(n + n_elements(elements), TYPE = size52(v, /TYPE))
	v_and_el[0] = v  &  v_and_el[n] = elements
	return, v_and_el
end
