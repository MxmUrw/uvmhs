module UVMHS.Lib.Pretty.DerivedInstances where

import UVMHS.Core
import UVMHS.Lib.Pretty.Deriving
import UVMHS.Lib.Pretty.Annotation
import UVMHS.Lib.Pretty.Color

makePrettySum ''𝑂
makePrettySum ''(∨)

makePrettyUnion ''ID

makePrettySum ''Color3Bit
makePrettySum ''Color
makePrettySum ''Formats
