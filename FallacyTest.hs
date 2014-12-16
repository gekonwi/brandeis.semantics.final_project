import Test.HUnit
import Fallacy

import Data.Logic.Propositional
--tests = test [ 
--             "test triple" ~: "Triple(Max,is,cat)" ~: "Triple \"Max\" \"is\" \"cat\"" ~=? show(Triple "Max" "is" "cat")
--             ]

a = var 'a'
b = var 'b'
c = var 'c'
d = var 'd'

{-
================================================================================
assertEqualTest
================================================================================

a shortcut for creating TestCase elements of the form
testName = TestCase $ assertEqual "" True (someExpression)

parameters:
	a:	expected value
	a:	actual value

returns:
	the test resulting from comparing expected with actual value
-}
assertEqualTest :: (Eq a, Show a) => a -> a -> Test
assertEqualTest expected actual = 
	TestCase $ assertEqual "" expected actual



{-
================================================================================
hasFallacyTest
================================================================================

Creates a test which checks if the given input expression contains the 
given fallacy with the given fallacy pattern (expressing the variable 
mapping).

parameters:
	
	Expr:	the expression to be given as input to findFallacies
	
	FoundFallacy: the FoundFallacy to look for in the findFallacies output

	Bool:	True if the fallacy is expected to be contained in the findFallacies
		output, False otherwise
	
returns:

	Test:	a test which checks if findFallacies output contains the expected
		FoundFallacy
-}
hasFallacyTest :: Expr -> FoundFallacy -> Bool -> Test
hasFallacyTest inputExpr foundFallacy shouldContain = 
	assertEqualTest shouldContain $ elem foundFallacy $ findFallacies inputExpr


{-
================================================================================
parse
================================================================================

Shortcut for parsing expressions.

parameters:
	String:	input, parsable by Data.Logic.Propositional.parseExpr
		
returns:
	Expr:	the parsed expression from the input
-}
parse :: String -> Expr
parse input = case parseExpr "" input of
	Left ex -> error $ "cannot parse: " ++ input
	Right val -> val

{-
================================================================================
affirmDisjunctPosTest
================================================================================

The pattern for 'Affirming a Disjunct' fallacy is
(a | b) & a -> ~b

there is asertBool which has the functionality of 'assertTrue'
but since it is called so confusingly, I preferred the unambiguous
assertEquel True ...
-}
affirmDisjunctPosTest = hasFallacyTest expr expFoundFallacy True
	where
		complexA = parse "(a & c) & d"			-- reducable to a
		complexA2 = parse "a & (c -> a)" 		-- reducable to a
		complexB = parse "b & d"				-- reducable to b
		complexNegB = parse "c & (c -> ~b)" 	-- reducable to ~b
		
		exprLeft = (complexA `disj` complexB) `conj` complexA2
		exprRight = complexNegB
		expr = exprLeft `cond` exprRight

		expFalExpr = parse "((a | b) & a) -> ~b"
		expFoundFallacy = FoundFallacy AffirmDisjunct expFalExpr expr


{-
================================================================================
affirmDisjunctNegTest
================================================================================
-}
affirmDisjunctNegTest = hasFallacyTest expr unwantedFallacy False
	where
		complexA = parse "(a & c) & d" 				-- reducable to a
		complexA2 = parse "a & (c -> a)" 			-- reducable to a
		complexB = parse "b & d" 					-- reducable to b
		complexSomething = parse "d & (c -> b)" 	-- NOT reducable to b

		exprLeft = (complexA `disj` complexB) `conj` complexA2
		exprRight = neg complexSomething
		expr = exprLeft `cond` exprRight

		unwantedFalExpr = parse "((a | b) & a) -> ~b"
		unwantedFallacy = FoundFallacy AffirmDisjunct unwantedFalExpr expr


{-
================================================================================
affirmDisjunctChangedVarsTest
================================================================================
The pattern for 'Affirming a Disjunct' fallacy is
(a | b) & a -> ~b

This tests if the fallacy detection also works with
(c | d) & c -> ~d
-}
affirmDisjunctChangedVarsTest = hasFallacyTest expr expFoundFallacy True
	where
		complexC = parse "(c & c) & a"		-- reducable to c
		complexC2 = parse "c & (c | a)" 	-- reducable to c
		complexD = parse "a & (a -> d)"		-- reducable to d
		complexNegD = parse "~d & (a | b)" 	-- reducable to ~d
		
		exprLeft = (complexC `disj` complexD) `conj` complexC2
		exprRight = complexNegD
		expr = exprLeft `cond` exprRight

		expFalExpr = parse "((c | d) & c) -> ~d"
		expFoundFallacy = FoundFallacy AffirmDisjunct expFalExpr expr



{-
================================================================================
wrongFormatTest
================================================================================
A fallacy pattern always has the form (expr1 -> expr2).
This tests if the function can handle expressions of a different format
(which are therefore no fallacies) withour raising errors.
-}
wrongFormatTest = assertEqualTest True $ null $ findFallacies $ parse "a & ~a"


{-
================================================================================
denyAntecedentPosTest
================================================================================

The pattern for 'Denying the antecedent' fallacy is
(a -> b) & ~a -> ~b
-}

denyAntecedentPosTest = hasFallacyTest expr expFoundFallacy True
	where
		complexA = parse "(a & a) & a" 	-- reducable to a
		complexNegA = parse "~(c | a)" 	-- reducable to ~a
		complexB = parse "~(~b | d)"	-- reducable to b
		complexNegB = parse "~ ~ ~b"	-- reducable to ~b

		exprLeft = (complexA `cond` complexB) `conj` complexNegA
		exprRight = complexNegB
		expr = exprLeft `cond` exprRight

		expFalExpr = parse "((a -> b) & ~a) -> ~b"
		expFoundFallacy = FoundFallacy DenyAntecedent expFalExpr expr




{-
================================================================================
affirmConseqPosTest
================================================================================

The pattern for 'Affirming the consequent' fallacy is
(a -> b) & b -> a
-}

affirmConseqPosTest = hasFallacyTest expr expFoundFallacy True
	where
		complexA = parse "~ ~a" 		 -- reducable to a
		complexA2 = parse "~(c | ~a)" 	 -- reducable to a
		complexB = parse "~(~b | d)" 	 -- reducable to b
		complexB2 = parse "(b | c) & ~c" -- reducable to b

		exprLeft = (complexA `cond` complexB) `conj` complexB2
		exprRight = complexA2 `conj` complexB
		expr = exprLeft `cond` exprRight

		expFalExpr = parse "((a -> b) & b) -> a"
		expFoundFallacy = FoundFallacy AffirmConsequent expFalExpr expr


{-
================================================================================
affirmConseqPosTest2
================================================================================

The pattern for 'Affirming the consequent' fallacy is
(a -> b) & b -> a

Since some expressions, like the one in affirmConseqPosTest, contain both, 
'Affirming the consequent' fallacy and 'Denying the antecedent' fallacy,
this tests "pure" 'Affirming the consequent' fallacy (which is not 'Denying 
the antecedent' fallacy)
-}

affirmConseqPosTest2 = hasFallacyTest expr expFoundFallacy True
	where
		expr = parse "((a -> b) & b) -> a"
		expFoundFallacy = FoundFallacy AffirmConsequent expr expr

{-
================================================================================
noFallacyTest1
================================================================================

In one of our experiments the following expression was wrongly classified 
as fallacy:
~a & b -> ~a
-}
--noFallacyTest1 = assertEqualTest True $ null $ findFallacies expr
--	where
--		expr = parse "(~a & b) -> ~a"






{-
================================================================================
collection of all tests
================================================================================
-}
tests = TestList [
	TestLabel "affirmDisjunctPosTest" affirmDisjunctPosTest,
	TestLabel "affirmDisjunctNegTest" affirmDisjunctNegTest,
	TestLabel "affirmDisjunctChangedVarsTest" affirmDisjunctChangedVarsTest,
	TestLabel "wrongFormatTest" wrongFormatTest,
	TestLabel "denyAntecedentPosTest" denyAntecedentPosTest,
	TestLabel "affirmConseqPosTest" affirmConseqPosTest,
	--TestLabel "noFallacyTest1" noFallacyTest1,
	TestLabel "affirmConseqPosTest2" affirmConseqPosTest2
	]
