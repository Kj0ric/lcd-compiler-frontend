<h1 align="center">
    Compiler Frontend for LCD Language in C
</h1>

<div align="center">

[![PL](https://img.shields.io/badge/C-blue?style=for-the-badge&logo=c&logoColor=white)]()
[![Tools](https://img.shields.io/badge/Tools-Flex%20%7C%20Bison-green?style=for-the-badge)]()
[![Status](https://img.shields.io/badge/status-completed-green?style=for-the-badge)]()
[![License](https://img.shields.io/badge/license-MIT-red?style=for-the-badge)](https://github.com/Kj0ric/lcd-semantic-analyzer/blob/main/LICENSE)

</div>

The LCD Compiler Frontend is a tool for parsing and analyzing Logical Circuit Designer (LCD) language programs. It breaks down the compilation process into three critical stages: lexical analysis, syntax parsing, and semantic validation.

## Table of Contents
- [About the LCD Language](#about-the-lcd-language)
- [Features](#features)
- [Semantic Rules for LCD Programs](#semantic-rules-for-lcd-programs)
- [Setup and Usage](#setup-and-usage)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## About the LCD Language

The Logical Circuit Designer (LCD) is a domain-specific scripting language engineered for logic circuit design and simulation. Designed as a pedagogical tool for compiler construction and programming language theory, LCD provides a minimalistic yet powerful abstraction for expressing digital logic circuits.

The LCD language facilitates logic circuit design through three main sections:

1. **Declarations**:
   - Introduces inputs, nodes, and outputs.
   - Example:
     ```
     input X, Y, Z
     node A, B, C
     output W, U
     ```

2. **Assignments**:
   - Defines the logical relationships between inputs, nodes, and outputs.
   - Example:
     ```
     A = X or Y
     B = A xor Y
     W = A and not Z
     ```

3. **Evaluation**:
   - Tests the designed circuits with different input combinations.
   - Example:
     ```
     evaluate circuit1 (X = true, Y = false, Z = true)
     ```

### Grammar of the LCD Language
The grammar of the LCD language can be described using Backus-Naur Form (BNF) notation as follows:

```bnf
<program> ::= <lcd>

<lcd> ::= 
          | <declarations> <circuitDesign> <evaluations>

<declarations> ::= <declaration> 
                 | <declaration> <declarations>

<declaration> ::= <input>
                | <output>
                | <node>

<input> ::= "input" <identifierList>

<output> ::= "output" <identifierList>

<node> ::= "node" <identifierList>

<identifierList> ::= <identifier>
                   | <identifier> "," <identifierList>

<circuitDesign> ::= <assignment>
                  | <assignment> <circuitDesign>

<assignment> ::= <identifier> "=" <expression>

<expression> ::= "not" <expression>
               | "(" <expression> ")"
               | <identifier>
               | <expression> "and" <expression>
               | <expression> "or" <expression>
               | <expression> "xor" <expression>
               | "true"
               | "false"

<evaluations> ::= <evaluation>
                | <evaluation> <evaluations>

<evaluation> ::= "evaluate" <identifier> "(" <evaluationAssignmentList> ")"

<evaluationAssignmentList> ::= <evaluationAssignment>
                             | <evaluationAssignment> "," <evaluationAssignmentList>

<evaluationAssignment> ::= <identifier> "=" "true"
                         | <identifier> "=" "false"
```

## Features

- **Lexical Analysis**: Tokenization of LCD language constructs
- **Syntax Parsing**: Grammatical structure validation
- **Semantic Analysis**: Error detection and type checking
- **Symbol Table Management**: Tracking variable declarations and usage
- **Comprehensive Error Reporting**: Detailed error messages with line numbers

## Semantic Rules for LCD Programs

1. **Undeclared Identifiers**: All variables must be declared before use in circuit design or evaluation blocks.

2. **Multiple Declarations**: An identifier cannot be declared more than once, even across different declaration types.

3. **Unused Inputs and Nodes**: Every input and node must be used in circuit design expressions.

4. **Unassigned Nodes and Outputs**: Every node and output must receive exactly one assignment in the circuit design block.

5. **Multiple Assignments**: A node or output cannot be assigned multiple times in the circuit design block.

6. **Unassigned Inputs in Evaluations**: Every input must be assigned a value in each circuit evaluation statement.

7. **Multiple Input Assignments**: An input cannot be assigned multiple times within a single evaluation statement.

8. **Incorrect Input Assignments**: Inputs can only be assigned values during circuit evaluations, not in the circuit design block.

9. **Incorrect Node/Output Assignments**: Nodes and outputs can only be assigned in the circuit design block, not during evaluations.

## Setup and Usage

### Prerequisites
- GCC Compiler (version 9.0+)
- Flex (version 2.6+)
- Bison (version 3.5+)

### Installation

#### 1. System Dependencies
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install gcc flex bison

# macOS (using Homebrew)
brew install gcc flex bison

# Arch Linux
sudo pacman -S gcc flex bison
```

#### 2. Clone Repository
```bash
git clone https://github.com/Kj0ric/lcd-compiler-frontend.git
cd lcd-compiler-frontend
```

### Compilation and Build

```bash
# Generate lexical analyzer
flex lcd_scanner.flx

# Generate parser
bison -d lcd_parser.y

# Compile the compiler
gcc -o lcd-compiler lex.yy.c lcd_parser.tab.c -lfl
```

### Usage

```bash
# Check LCD program syntax and semantics
./lcd-compiler < input.lcd
```

```bash
# Redirect output to file for comprehensive error logging
./lcd-compiler < input.lcd > compilation_errors.txt
```

### Output Scenarios

#### Empty Program
If the program is empty, the tool should not print anything since an empty program is a valid program.

#### Grammatical Errors
If the program is not grammatically correct, the tool should output `ERROR`without any additional details. For the following program:
```lcd
input A, Y
output K
evaluate myCirc(A = true, Y = false)
```
Output:
```
ERROR
```

#### Semantic Errors 
If program is grammatically correct but contains violations of the semantic rules then the output should display all the semantic errors.

```lcd
input X, Y
node A
output Z
A = X and Y
Z = A or not B
evaluate test1 (X = true, Y = false, Y = true)
evaluate test2 (X = false)

```
Output:
```
ERROR at line 5: B is undeclared.
ERROR at line 6: Y is already assigned.
ERROR at line 7: Y is not assigned. 

```

#### Valid Evaluation
If program is both grammatically and semantically correct, then the output should display the evaluation results.
```lcd
input input1, input2
node node1, node2
output output1, output2

node1 = node2 xor not input2
node 2 = not input1
output1 = input2 and node1
output2 = node1 or not node2

evaluate circuit1 (input1 = true, input2 = true)
evaluate circuit2 (input2 = true, input1 = false)
```
Output:
```
circuit1:output1=false,output2=true
circuit2:output1=true,output2=true
```

### Example Workflow
```bash
# Compile the compiler
gcc -o lcd-compiler lex.yy.c lcd_parser.tab.c -lfl

# Validate a sample circuit
./lcd-compiler tests/sample_circuit.lcd

# Run multiple test cases
for file in tests/*.lcd; do
    ./lcd-compiler "$file"
done
```

## License
This project is licensed under the MIT License - see the [LICENSE](/LICENSE) file for details.

## Acknowledgements
This project was developed as part of the Programming Languages course at Sabanci University. Special thanks to the course instructor Hüsnü Yenigün and the teaching assistants for their guidance and support.
