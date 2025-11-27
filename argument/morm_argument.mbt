///|
pub(open) trait MormArgument: Show {
  value(self : Self) -> @ty.MormType
}

///|
pub type MormArguments = FixedArray[&MormArgument]
