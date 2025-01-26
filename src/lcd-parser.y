%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lcd-parser.h"
void yyerror (const char *msg) /* Called by yyparse on error */ { return; }

extern int yylex();

Identifier** declarations;
int declarations_size = 100, declarations_index = 0;

Identifier** inputs;
int inputs_size = 100, inputs_index = 0;

Identifier** nodes;
int nodes_size = 100, nodes_index = 0;

Identifier** outputs;
int outputs_size = 100, outputs_index = 0;

ErrorMessage** errors;
int errors_size = 100, errors_index = 0;

int semantic_error = 0; // To indicate that there is an semantic error

char** eval_outputs = NULL;
int eval_outputs_size = 100;  
int eval_outputs_index = 0; 
%}

%union{
  Identifier* identifierPtr;
  TreeNode* treeNodePtr;
  int value;
  int line_no;
  int col_no;
}

%token <identifierPtr> tIDENTIFIER
%token <line_no> tEVALUATE
%token <col_no> tRPR
%type <identifierPtr> identifierList
%type <value> booleanValue
%token tINPUT tOUTPUT tNODE tOR tAND tXOR tNOT tASSIGNMENT tCOMMA tLPR
%token <value> tTRUE tFALSE
%type <treeNodePtr> expression

%left tOR tXOR
%left tAND
%precedence tNOT

%start program
%%
program : lcd
;

lcd : 
    | declarations circuitDesign evaluations
;

declarations : declaration 
             | declaration declarations
;

declaration : input 
            | output 
            | node
;

input : tINPUT identifierList {
  Identifier* iter = $2;
  addDeclaration(iter, "input");  // Checks RULE 2
}
;

output : tOUTPUT identifierList {
  Identifier* iter = $2;
  addDeclaration(iter, "output"); // Checks RULE 2
}
;

node : tNODE identifierList {
  Identifier* iter = $2;
  addDeclaration(iter, "node");   // Checks RULE 2
  //printArrays();
}
;

identifierList : tIDENTIFIER {
  // This is the base case where we create the first identifier in the chain
  $$ = $1; 
}
| tIDENTIFIER tCOMMA identifierList {
  $1->next = $3;  // $3 is the existing list of identifiers
  $$ = $1;        // The new identifier becomes the head of the list
}
;

circuitDesign : assignment 
              | assignment circuitDesign
;

assignment : tIDENTIFIER tASSIGNMENT expression {
  int idx;

  // 1. Check if the identifier exists in nodes
  if ((idx = isDeclaredInArray(nodes, nodes_index, $1)) != -1){
    markAsAssignedInArray(nodes, idx, $1); // Check RULE 5
    nodes[idx]->exprTree = $3;

    // Evaluate the expression and store the value in the node
    //nodes[idx]->value = evaluateExprTree(nodes[idx]->exprTree); 
  }

  // 2. Check if the identifier exists in outputs
  else if ((idx = isDeclaredInArray(outputs, outputs_index, $1)) != -1) {
    // RULE 5: Multiple assignments to node/output
    markAsAssignedInArray(outputs, idx, $1); // Check RULE 5
    outputs[idx]->exprTree = $3;

    // Evaluate the expression and store the value in the output
    //outputs[idx]->value = evaluateExprTree(outputs[idx]->exprTree);  
  }

  // 3. Check if the identifier exists in inputs
  else if ((idx = isDeclaredInArray(inputs, inputs_index, $1)) != -1) {
    // RULE 8: Incorrect assignment to input
    char errorMsg[256];
    snprintf(errorMsg, sizeof(errorMsg),
              "ERROR at line %d: %s is already assigned.",
              $1->line_no, $1->name);
    addErrorMessage($1->line_no, $1->column_seen, errorMsg);
  }

  // 4. Undeclared
  else {
    // RULE 1: Undeclared identifier
    char errorMsg[256];
    snprintf(errorMsg, sizeof(errorMsg),
              "ERROR at line %d: %s is undeclared.",
              $1->line_no, $1->name);
    addErrorMessage($1->line_no, $1->column_seen, errorMsg);
  }

  // Check RHS 
  markAsUsedAndCheckForUndeclared($3);

  // Evaluate the expression

}
;

expression : tIDENTIFIER {
  $$ = mkExprNodeIdentifier($1->name, $1->line_no, $1->column_seen);
}
| tTRUE                       {
  $$ = mkExprNodeValue(1);
}
| tFALSE                      {
  $$ = mkExprNodeValue(0);
}
| tNOT expression             {
  $$ = mkExprNodeUnary($2, OP_NOT);
}
| expression tAND expression  {
  $$ = mkExprNodeBinary($1, $3, OP_AND);
}
| expression tOR expression   {
  $$ = mkExprNodeBinary($1, $3, OP_OR);
}
| expression tXOR expression  {
  $$ = mkExprNodeBinary($1, $3, OP_XOR);
}
| tLPR expression tRPR        {
  $$ = $2;
}
;

evaluations : evaluation 
            | evaluation evaluations
;

evaluation : tEVALUATE tIDENTIFIER tLPR evaluationAssignmentList tRPR {
  checkForUnassignedInput($1, $5); // Check RULE 6
  evaluateAllNodesAndOutputs();
  storeEvaluationResults($2->name);

  // Reset assignment status and values of all inputs for the current evaluation
  for (int i = 0; i < inputs_index; i++) {
      inputs[i]->is_assigned_in_eval = 0;
      inputs[i]->value = -1;
  }
}
;

evaluationAssignmentList : evaluationAssignment {
}
                         | evaluationAssignment tCOMMA evaluationAssignmentList
;

evaluationAssignment : tIDENTIFIER tASSIGNMENT booleanValue {
  int idx = isDeclaredInArray(declarations, declarations_index, $1);
  if (idx == -1) {
    // RULE 1: Undeclared identifier
    char errorMsg[256];
    snprintf(errorMsg, sizeof(errorMsg),
              "ERROR at line %d: %s is undeclared.",
              $1->line_no, $1->name);
    addErrorMessage($1->line_no, $1->column_seen, errorMsg);
  }
  else {
    // If it's input
    if ((idx = isDeclaredInArray(inputs, inputs_index, $1)) != -1) {
      markAsAssignedInEval(idx, $1);
      inputs[idx]->value = $3;  // Assign the boolean value (T/F)
    }
    // If it's node or output
    else {
      // RULE 9: INCORRECT ASSIGNMENT TO NODE/OUTPUT
      char errorMsg[256];
      snprintf(errorMsg, sizeof(errorMsg),
                "ERROR at line %d: %s is not an input.",
                $1->line_no, $1->name);
      addErrorMessage($1->line_no, $1->column_seen, errorMsg);
    }
  }
}
;

booleanValue: tTRUE {$$ = 1;}
            | tFALSE {$$ = 0;}
;

%%
/*-------  Declarations API -------*/
void printArrays(){
  for (int i = 0; i < declarations_index; i++){
    printf("Declaration name: %s, Type: %s, Line: %d\n", declarations[i]->name, declarations[i]->type, declarations[i]->line_no);
  }
  for (int i = 0; i < inputs_index; i++){
    printf("Input name: %s, Type: %s, Line: %d\n", inputs[i]->name, inputs[i]->type, inputs[i]->line_no);
  }
  for (int i = 0; i < nodes_index; i++){
    printf("Node name: %s, Type: %s, Line: %d\n", nodes[i]->name, nodes[i]->type, nodes[i]->line_no);
  }
  for (int i = 0; i < outputs_index; i++){
    printf("Output name: %s, Type: %s, Line: %d\n", outputs[i]->name, outputs[i]->type, outputs[i]->line_no);
  }
}

void resizeInputs(){
  inputs_size *= 2;
  inputs = realloc(inputs, inputs_size * sizeof(Identifier*));
  if (inputs == NULL) {
    fprintf(stderr, "Memory allocation failed during resizing\n");
    exit(1);
  }
}

void resizeNodes(){
  nodes_size *= 2;
  nodes = realloc(nodes, nodes_size * sizeof(Identifier*));
  if (nodes == NULL) {
    fprintf(stderr, "Memory allocation failed during resizing\n");
    exit(1);
  }
}

void resizeOutputs(){
  outputs_size *= 2;
  outputs = realloc(outputs, outputs_size * sizeof(Identifier*));
  if (outputs == NULL) {
    fprintf(stderr, "Memory allocation failed during resizing\n");
    exit(1);
  }
}

void resizeDeclarations(){
  declarations_size *= 2;
  declarations = realloc(declarations, declarations_size * sizeof(Identifier*));
  if (declarations == NULL) {
    fprintf(stderr, "Memory allocation failed during resizing\n");
    exit(1);
  }
}

void addToGeneralDeclarations(Identifier* identifier){
  if (declarations_index < declarations_size) {
    declarations[declarations_index] = identifier;
    declarations_index++;
  }
  else {
    resizeDeclarations();
    declarations[declarations_index] = identifier;
    declarations_index++;
  }
}

int isDeclaredInArray(Identifier** array, int count, Identifier* identifier) {
  for (int i = 0; i < count; i++) {
    if (strcmp(identifier->name, array[i]->name) == 0) {
      return i; // Found, return index
    }
  }
  return -1; // Not found 
}

void markAsUsedInArray(Identifier** array, int idx) {
  if (array[idx]->is_used == 0)
    array[idx]->is_used = 1;
}

void markAsAssignedInArray(Identifier** array, int idx, Identifier* id) {
  if (array[idx]->is_assigned == 0)
    array[idx]->is_assigned = 1;  
  else {
    // RULE 5: MULTIPLE ASSIGNMENTS
    char errorMsg[256];
    snprintf(errorMsg, sizeof(errorMsg),
              "ERROR at line %d: %s is already assigned.",
              id->line_no, id->name);
    addErrorMessage(id->line_no, id->column_seen, errorMsg);
  }
} 

void markAsAssignedInEval(int idx, Identifier* id) {
  if (inputs[idx]->is_assigned_in_eval == 0)
    inputs[idx]->is_assigned_in_eval = 1;
  else {
    // RULE 7: MULTIPLE ASSIGNMENTS IN EVALUATION
    char errorMsg[256];
    snprintf(errorMsg, sizeof(errorMsg),
              "ERROR at line %d: %s is already assigned.",
              id->line_no, id->name);
    addErrorMessage(id->line_no, id->column_seen, errorMsg);
  }
} 
/*------- Functions to create things -------*/
TreeNode* mkExprNodeIdentifier(const char* identifier, int line_no, int column_no){
  TreeNode* node = (TreeNode*)malloc(sizeof(TreeNode));
  node->exprNodePtr = (ExprNode*)malloc(sizeof(ExprNode));

  node->thisNodeType = EXPR_NODE_IDENTIFIER;
  node->exprNodePtr->exprNodeIdentifier.identifierPtr = (Identifier*)malloc(sizeof(Identifier));
  node->exprNodePtr->exprNodeIdentifier.identifierPtr->name = strdup(identifier);
  node->exprNodePtr->exprNodeIdentifier.identifierPtr->line_no = line_no;
  node->exprNodePtr->exprNodeIdentifier.identifierPtr->column_seen = column_no;
  node->exprNodePtr->exprNodeIdentifier.identifierPtr->is_used= -1;
  node->exprNodePtr->exprNodeIdentifier.identifierPtr->type = "none";
  node->exprNodePtr->exprNodeIdentifier.identifierPtr->next = NULL;

  // Search for the identifier in inputs, nodes, and outputs and set the type accordingly
  for (int i = 0; i < inputs_index; i++) {
      if (strcmp(inputs[i]->name, identifier) == 0) {
          node->exprNodePtr->exprNodeIdentifier.identifierPtr->type = "input";
          return node;  // Return early if we find it in the inputs
      }
  }

  for (int i = 0; i < nodes_index; i++) {
      if (strcmp(nodes[i]->name, identifier) == 0) {
          node->exprNodePtr->exprNodeIdentifier.identifierPtr->type = "node";
          return node;  // Return early if we find it in the nodes
      }
  }

  for (int i = 0; i < outputs_index; i++) {
      if (strcmp(outputs[i]->name, identifier) == 0) {
          node->exprNodePtr->exprNodeIdentifier.identifierPtr->type = "output";
          return node;  // Return early if we find it in the outputs
      }
  }


  return node;
}

TreeNode* mkExprNodeValue(int value){
    TreeNode* node = (TreeNode*)malloc(sizeof(TreeNode));
    node->exprNodePtr = (ExprNode*)malloc(sizeof(ExprNode));

    node->thisNodeType = EXPR_NODE_VALUE;
    node->exprNodePtr->exprNodeValue.value = value;
    return node;
}

TreeNode* mkExprNodeBinary(TreeNode* left, TreeNode* right, OperatorType op){
  TreeNode* node = (TreeNode*)malloc(sizeof(TreeNode));
  node->exprNodePtr = (ExprNode*)malloc(sizeof(ExprNode));

  node->thisNodeType = EXPR_NODE_OPERATOR;
  node->exprNodePtr->exprNodeOperator.left = left;
  node->exprNodePtr->exprNodeOperator.right = right;
  node->exprNodePtr->exprNodeOperator.op_type = op;
  return node;
}

TreeNode* mkExprNodeUnary(TreeNode* child, OperatorType op){
  TreeNode* node = (TreeNode*)malloc(sizeof(TreeNode));
  node->exprNodePtr = (ExprNode*)malloc(sizeof(ExprNode));

  node->thisNodeType = EXPR_NODE_OPERATOR;
  node->exprNodePtr->exprNodeOperator.op_type = op;
  node->exprNodePtr->exprNodeOperator.left = child;
  node->exprNodePtr->exprNodeOperator.right = NULL;
  return node;
}
/* ------ Error Check API ------ */
void markAsUsedAndCheckForUndeclared(TreeNode* node){
  if (node == NULL)
    return;
  
  switch(node->thisNodeType) {
    case EXPR_NODE_IDENTIFIER:
      char* identifier_name = node->exprNodePtr->exprNodeIdentifier.identifierPtr->name;
      Identifier* identifierPtr = node->exprNodePtr->exprNodeIdentifier.identifierPtr;
      int idx;
      // Identifier is an input
      if ((idx = isDeclaredInArray(inputs, inputs_index, identifierPtr)) != -1) {
        markAsUsedInArray(inputs, idx);
      }
      // Identifier is a node
      else if ((idx = isDeclaredInArray(nodes, nodes_index, identifierPtr)) != -1) {
        markAsUsedInArray(nodes, idx);
      }
      // Identifier is an output
      else if ((idx = isDeclaredInArray(outputs, outputs_index, identifierPtr)) != -1) {

      }
      else{
        // RULE 1: Undecleared identifier
        char errorMsg[256];
        int id_line_no = node->exprNodePtr->exprNodeIdentifier.identifierPtr->line_no;
        int id_column_no = node->exprNodePtr->exprNodeIdentifier.identifierPtr->column_seen;
        snprintf(errorMsg, sizeof(errorMsg),
                  "ERROR at line %d: %s is undeclared.",
                  id_line_no, identifier_name);
        addErrorMessage(id_line_no, id_column_no, errorMsg);
      }

      break;

    case EXPR_NODE_OPERATOR:
      // Recursively check left and right operands
      if (node->exprNodePtr->exprNodeOperator.left) {
          markAsUsedAndCheckForUndeclared(node->exprNodePtr->exprNodeOperator.left);
      }
      if (node->exprNodePtr->exprNodeOperator.right) {
          markAsUsedAndCheckForUndeclared(node->exprNodePtr->exprNodeOperator.right);
      }
      break;

    case EXPR_NODE_VALUE:
      break;
    
    default:
      printf("Unknown node type\n");
      break;
  }
}

void addDeclaration(Identifier* iter, char* type) {
  while(iter != NULL) {
    int idx = isDeclaredInArray(declarations, declarations_index, iter);
    if (idx == -1) {
      iter->type = type;
       // Add to the appropriate array based on type
      if (strcmp(type, "input") == 0) {
        if (inputs_index >= inputs_size) resizeInputs();
        inputs[inputs_index++] = iter;
      } 
      else if (strcmp(type, "node") == 0) {
        if (nodes_index >= nodes_size) resizeNodes();
        nodes[nodes_index++] = iter;
      } 
      else if (strcmp(type, "output") == 0) {
        if (outputs_index >= outputs_size) resizeOutputs();
        outputs[outputs_index++] = iter;
      }

      // Add to general declarations array
      addToGeneralDeclarations(iter);
    }
    else {
      // RULE 2: Multiple declarations of the same identifier
      char errorMsg[256];
      if (strcmp(declarations[idx]->type, "input") == 0){
        snprintf(errorMsg, sizeof(errorMsg), "ERROR at line %d: %s is already declared as an input.",
                iter->line_no, iter->name);
      }
      else if (strcmp(declarations[idx]->type, "node") == 0){
        snprintf(errorMsg, sizeof(errorMsg), "ERROR at line %d: %s is already declared as a node.",
                iter->line_no, iter->name);
      }
      else if (strcmp(declarations[idx]->type, "output") == 0){
        snprintf(errorMsg, sizeof(errorMsg), "ERROR at line %d: %s is already declared as an output.",
                iter->line_no, iter->name);
      }
      addErrorMessage(iter->line_no, iter->column_seen, errorMsg);
    }
    iter = iter->next;
  }
}

void checkForUnusedInputNode() {
  // Check inputs array for unused inputs
  for (int i = 0; i < inputs_index; i++) {
    if (inputs[i]->is_used == 0) {
      // RULE 3: UNUSED INPUTS AND NODES
      char errorMsg[256];
      snprintf(errorMsg, sizeof(errorMsg),
              "ERROR at line %d: %s is not used.",
              inputs[i]->line_no, inputs[i]->name);
      addErrorMessage(inputs[i]->line_no, inputs[i]->column_seen, errorMsg);
    }
  }
  
  // Check output array for unused outputs
  for (int i = 0; i < nodes_index; i++) {
    if (nodes[i]->is_used == 0) {
      // RULE 3: UNUSED INPUTS AND NODES
      char errorMsg[256];
      snprintf(errorMsg, sizeof(errorMsg),
              "ERROR at line %d: %s is not used.",
              nodes[i]->line_no, nodes[i]->name);
      addErrorMessage(nodes[i]->line_no, nodes[i]->column_seen, errorMsg);
    }
  }
}

void checkForUnassignedNodeOutput() {
    // Check nodes for unassigned nodes
    for (int i = 0; i < nodes_index; i++) {
        if (nodes[i]->is_assigned == 0) {
          // RULE 4: UNASSIGNED NODE/OUTPUT
          char errorMsg[256];
          snprintf(errorMsg, sizeof(errorMsg),
                  "ERROR at line %d: %s is not assigned.",
                  nodes[i]->line_no, nodes[i]->name);
          addErrorMessage(nodes[i]->line_no, nodes[i]->column_seen, errorMsg);
        }
    }

    // Check outputs for unassigned outputs
    for (int i = 0; i < outputs_index; i++) {
        if (outputs[i]->is_assigned == 0) {
          // RULE 4: UNASSIGNED NODE/OUTPUT
          char errorMsg[256];
          snprintf(errorMsg, sizeof(errorMsg),
                  "ERROR at line %d: %s is not assigned.",
                  outputs[i]->line_no, outputs[i]->name);
          addErrorMessage(outputs[i]->line_no, outputs[i]->column_seen, errorMsg);
        }
    }
}

void checkForUnassignedInput(int line_no, int col_no_RPR) {
    for (int i = 0; i < inputs_index; i++) {
        if (inputs[i]->is_assigned_in_eval == 0) {
          // RULE 6: Unassigned input 
          char errorMsg[256];
          snprintf(errorMsg, sizeof(errorMsg),
                  "ERROR at line %d: %s is not assigned.",
                  line_no, inputs[i]->name);
          addErrorMessage(line_no, col_no_RPR, errorMsg);
        }
    }
}

/* ------ Evaluation API ------ */
int evaluateExprTree(TreeNode* node) {
    // Base case: NULL node
    if (node == NULL) {
        return 0; // Default value for null nodes (e.g., no expression to evaluate)
    }
    // Leaf node: Identifier
    if (node->thisNodeType == EXPR_NODE_IDENTIFIER) {
      int value;
      char *identifierName = node->exprNodePtr->exprNodeIdentifier.identifierPtr->name;

      // Fetch input value using the identifier's name (this assumes the identifier is in the inputs array)
      if (strcmp(node->exprNodePtr->exprNodeIdentifier.identifierPtr->type, "input") == 0) {
        // Search for the input in the inputs array by name
        for (int i = 0; i < inputs_index; i++) {
            if (strcmp(inputs[i]->name, identifierName) == 0) {
                value = inputs[i]->value;  // Return the value of the input
                return value;
            }
        }
      }
      else {
        value = findAndEvaluate(identifierName);
      }
      if (value == -1) {
        printf("ERROR: Undeclared input %s encountered during evaluation.\n", 
                node->exprNodePtr->exprNodeIdentifier.identifierPtr->name);
        exit(1); // Exit on error
      }
      return value; // Return the input value (0 or 1)
    }

    // Leaf node: Boolean value (T/F)
    if (node->thisNodeType == EXPR_NODE_VALUE) {
        return node->exprNodePtr->exprNodeValue.value; // Return the constant value (0 or 1)
    }

    // Operator node: Evaluate left and right subtrees
    if (node->thisNodeType == EXPR_NODE_OPERATOR) {
        ExprNodeOperator* opNode = &node->exprNodePtr->exprNodeOperator;

        // Recursively evaluate the left and right operands
        int leftVal = evaluateExprTree(opNode->left);
        int rightVal = evaluateExprTree(opNode->right);

        // Apply the operator
        switch (opNode->op_type) {
            case OP_AND: return leftVal && rightVal;
            case OP_OR:  return leftVal || rightVal;
            case OP_XOR: return leftVal != rightVal; // XOR: 1 if different, 0 if same
            case OP_NOT: return !leftVal; // Unary NOT, only use left child
            default:
                printf("ERROR: Unknown operator encountered during evaluation.\n");
                exit(1);
        }
    }

    // If we reach here, it means the node type is invalid
    return -1;
}

void storeEvaluationResults(const char* circuitName) {
    // Create a buffer to store the result for the current circuit
    char result_buffer[1024]; // Adjust the size as needed, this should be large enough for your output
    snprintf(result_buffer, sizeof(result_buffer), "%s:", circuitName); // Start with circuit name

    // Iterate over the outputs and store their values in the buffer
    for (int i = 0; i < outputs_index; i++) {
        // Append the output name and value in the desired format
        if (outputs[i]->value == 0) {
            snprintf(result_buffer + strlen(result_buffer), sizeof(result_buffer) - strlen(result_buffer), "%s=%s", outputs[i]->name, "false");
        } else if (outputs[i]->value == 1) {
            snprintf(result_buffer + strlen(result_buffer), sizeof(result_buffer) - strlen(result_buffer), "%s=%s", outputs[i]->name, "true");
        }

        // Add a comma if not the last output
        if (i < outputs_index - 1) {
            snprintf(result_buffer + strlen(result_buffer), sizeof(result_buffer) - strlen(result_buffer), ",");
        }
    }

    // Add the result to eval_outputs
    if (eval_outputs_index >= eval_outputs_size) {
        eval_outputs_size *= 2;  // Double the size if the array is full
        eval_outputs = realloc(eval_outputs, eval_outputs_size * sizeof(char*));
        if (eval_outputs == NULL) {
            printf("ERROR: Failed to reallocate memory for eval_outputs.\n");
            exit(1);
        }
    }

    // Allocate memory for the result string and copy it into eval_outputs
    eval_outputs[eval_outputs_index] = strdup(result_buffer);
    eval_outputs_index++;  // Increase the index for the next evaluation
}

void printAllEvaluationResults() {
    // Iterate over all stored evaluation results
    for (int i = 0; i < eval_outputs_index; i++) {
        // Print each message stored in eval_outputs
        printf("%s\n", eval_outputs[i]);
    }
}

void evaluateAllNodesAndOutputs() {
    // Evaluate the expressions for all nodes
    for (int i = 0; i < nodes_index; i++) {
        // Evaluate the expression for the current node
        nodes[i]->value = evaluateExprTree(nodes[i]->exprTree);
    }

    // Evaluate the expressions for all outputs
    for (int i = 0; i < outputs_index; i++) {
        // Evaluate the expression for the current output
        outputs[i]->value = evaluateExprTree(outputs[i]->exprTree);
    }
}

int findAndEvaluate(const char* name) {
    // Check nodes array
    for (int i = 0; i < nodes_index; i++) {
        if (strcmp(nodes[i]->name, name) == 0) {
            // If we find the node, evaluate its expression tree
            return evaluateExprTree(nodes[i]->exprTree);
        }
    }

    // Check outputs array
    for (int i = 0; i < outputs_index; i++) {
        if (strcmp(outputs[i]->name, name) == 0) {
            // If we find the output, evaluate its expression tree
            return evaluateExprTree(outputs[i]->exprTree);
        }
    }
}


/* ------ Error API ----- */
void addErrorMessage(int line_no, int column_no, const char* msg) {
    if (errors_index >= errors_size) {
        errors_size *= 2;  // Resize the error array
        errors = realloc(errors, errors_size * sizeof(ErrorMessage*));
        if (errors == NULL) {
          fprintf(stderr, "Memory allocation failed during realloc\n");
          exit(1);
        }
    }
    errors[errors_index] = (ErrorMessage*)malloc(sizeof(ErrorMessage));
    if (errors[errors_index] == NULL) {
      fprintf(stderr, "Memory allocation failed for ErrorMessage\n");
      exit(1);
    }
    errors[errors_index]->line_encountered = line_no;
    errors[errors_index]->column_encountered = column_no;
    errors[errors_index]->message = strdup(msg);
    errors_index++;
    
    if (semantic_error == 0)
      semantic_error = 1;  // Set the semantic error flag
}

void printErrors() {
  if (errors_index > 0) {
    // Sort errors by line and column
    qsort(errors, errors_index, sizeof(ErrorMessage*), compareErrors);
    // Print each error message
    for (int i = 0; i < errors_index; i++) {
        printf("%s\n", errors[i]->message);
        //free(errors[i]); // Clean up dynamically allocated memory
    }
    //free(errors);
  }
}

int compareErrors(const void* a, const void* b) {
    ErrorMessage* errorA = *(ErrorMessage**)a;  // Convert the void pointers to Error pointers
    ErrorMessage* errorB = *(ErrorMessage**)b;

    // Compare line numbers first
    if (errorA->line_encountered != errorB->line_encountered) {
        return errorA->line_encountered - errorB->line_encountered;  // Return the difference of line numbers
    }

    // If the line numbers are the same, compare column numbers
    return errorA->column_encountered - errorB->column_encountered;  // Return the difference of column numbers
}

void initializeGlobals() {
  declarations = (Identifier**)malloc(declarations_size * sizeof(Identifier*));
  inputs = (Identifier**)malloc(inputs_size * sizeof(Identifier*));
  nodes = (Identifier**)malloc(nodes_size * sizeof(Identifier*));
  outputs = (Identifier**)malloc(outputs_size * sizeof(Identifier*));
  //expressions = (ExprNode**)malloc(expr_size * sizeof(ExprNode*));
  errors = (ErrorMessage**)malloc(errors_size * sizeof(ErrorMessage*));
  eval_outputs = (char**)malloc(eval_outputs_size * sizeof(char*));

  // Initialize all entries to NULL
  for (int i = 0; i < errors_size; i++) {
    errors[i] = NULL;
  }
}

void freeAllTreeNodes() {
  for (int i = 0; i < nodes_size; i++) {
    if (nodes[i]->exprTree != NULL) {
        freeTreeNode(nodes[i]->exprTree);
    }
  }

  for (int i = 0; i < outputs_size; i++) {
    if (outputs[i]->exprTree != NULL) {
        freeTreeNode(outputs[i]->exprTree);
    }
  }
}

void freeTreeNode(TreeNode* node) {
  if (node == NULL) return;

  // Recursively free left and right subtrees if the node is an operator node
  if (node->thisNodeType == EXPR_NODE_OPERATOR) {
    if (node->exprNodePtr->exprNodeOperator.left != NULL){
      freeTreeNode(node->exprNodePtr->exprNodeOperator.left);
    }
    if (node->exprNodePtr->exprNodeOperator.right != NULL){
      freeTreeNode(node->exprNodePtr->exprNodeOperator.right);
    }
  }

  // Free the identifier name if the node is an identifier
  if (node->thisNodeType == EXPR_NODE_IDENTIFIER) {
    if (node->exprNodePtr->exprNodeIdentifier.identifierPtr != NULL) {
      free(node->exprNodePtr->exprNodeIdentifier.identifierPtr);
    }
  }

  // Free the expression node itself
  if (node->exprNodePtr != NULL) {
    free(node->exprNodePtr);
  }
  
  // Finally, free the TreeNode structure
  free(node);
}

int main () 
{
  initializeGlobals();
  if (yyparse()) {
    printf("ERROR\n");
    return 1;
  } 
  else {
    checkForUnusedInputNode();      // Check RULE 3
    checkForUnassignedNodeOutput(); // Check RULE 4
    if (semantic_error) {
      printErrors();
      return 1;
    }
    else {
      printAllEvaluationResults();
      return 0;
    }
  }
}