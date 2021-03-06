module Fallacy.LogicalShortcuts where

import Data.Logic.Propositional

var = Variable . Var
neg = Negation
conj = Conjunction
disj = Disjunction
cond = Conditional
iff = Biconditional
