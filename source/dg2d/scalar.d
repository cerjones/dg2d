/**
  This module defines the scalar type used for the vector geometry.

  Copyright: Chris Jones
  License: Boost Software License, Version 1.0
  Authors: Chris Jones
*/

module dg2d.scalar;

/**
  Scalar, the basic scalar type is single precision float.
*/

alias Scalar = double;

/*
  Returns true if T is a implicitly convertable to Scalar
  TODO: should this support long, short, byte etc??
*/ 

enum bool canConvertToScalar(T) = (is(T == float) || is(T == double) || is(T == int));

// TODO - Add a rotation struct, sin & cos pair that used to rotate ??

// Coefficents for making cirlces from bezier curves
// Ie, quater unit circle is 1,0 --> 1,CBezOutset, --> CBezOutset,1 --> 0,1 

enum Scalar CBezOutset = 0.551915324; // outset from bezier end point
enum Scalar CBezInset = 0.448084676; // inset from bounding box (1-outset)

