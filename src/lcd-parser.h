#ifndef PARSER_H
#define PARSER_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------ SCANNER TYPES ------ */
typedef struct Identifier{
    char* name;
    int line_no;
    char* type;
    int is_used;
    int is_assigned;
    int is_assigned_in_eval;
    int column_seen;
    struct Identifier* next;
    struct TreeNode* exprTree;
    int value;
} Identifier;

/* ------ PARSER TYPES ------ */
typedef struct ErrorMessage {
    int line_encountered;
    int column_encountered;
    char* message;
} ErrorMessage;

typedef enum {
    EXPR_NODE_IDENTIFIER,
    EXPR_NODE_VALUE,
    EXPR_NODE_OPERATOR
} ExprNodeType; 

typedef enum {
    OP_AND,
    OP_OR,
    OP_XOR,
    OP_NOT,
    OP_NONE
} OperatorType;

typedef struct ExprNodeIdentifier {
    Identifier* identifierPtr;       
    int value;
    struct ExprNodeIdentifier* next;        // Line number of the expression in the input source
} ExprNodeIdentifier;

typedef struct ExprNodeOperator {
    OperatorType op_type;   // The operator type (AND, OR, XOR, NOT)
    struct TreeNode* left;  // Left operand
    struct TreeNode* right; // Right operand
} ExprNodeOperator;

typedef struct ExprNodeValue {
    int value;              // The value of the node (for constants)
} ExprNodeValue;

typedef union {
    ExprNodeIdentifier exprNodeIdentifier;
    ExprNodeOperator exprNodeOperator;
    ExprNodeValue exprNodeValue;
} ExprNode;

typedef struct TreeNode {
    ExprNodeType thisNodeType;
    ExprNode *exprNodePtr;
} TreeNode;

/* ------ FUNCTION DECLARATIONS ------ */
void printArrays();
void resizeInputs();
void resizeNodes();
void resizeOutputs();
void resizeDeclarations();
void addToDeclarations(Identifier*);
int isDeclaredInArray(Identifier**, int, Identifier*);
void markAsUsedInArray(Identifier**, int);
void markAsAssignedInArray(Identifier**, int, Identifier*);
void markAsAssignedInEval(int, Identifier*);

TreeNode* mkExprNodeIdentifier(const char*, int, int);
TreeNode* mkExprNodeValue(int);
TreeNode* mkExprNodeBinary(TreeNode*, TreeNode*, OperatorType);
TreeNode* mkExprNodeUnary(TreeNode*, OperatorType);

void markAsUsedAndCheckForUndeclared(TreeNode*);
void addDeclaration(Identifier*, char*);
void checkForUnusedInputNode();
void checkForUnassignedNodeOutput();
void checkForUnassignedInput(int, int);

int evaluateExprTree(TreeNode*);
void storeEvaluationResults(const char*);
void printAllEvaluationResults();
void evaluateAllNodesAndOutputs();
int findAndEvaluate(const char*);

void addErrorMessage(int, int, const char*);
void printErrors();
int compareErrors(const void*, const void*);
void initializeGlobals();

void freeAllTreeNodes();
void freeTreeNode(TreeNode*);

#endif