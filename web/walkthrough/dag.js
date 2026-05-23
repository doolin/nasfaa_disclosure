// dag.js — DAG walker for nasfaa_questions.yml (consumed as questions.json)
//
// JS port of lib/nasfaa/walkthrough.rb's DAG-navigation logic, minus the
// terminal I/O. Holds the current node, accepts y/n answers, follows
// on_yes / on_no edges, and accumulates booleans into an inputs bag.
//
// At a terminal (result) node it returns the result node verbatim, along
// with the accumulated inputs and the path of question node IDs traversed.
//
// The caller is expected to cross-verify by passing `inputs` into
// engine.js' RuleEngine.evaluate and confirming the rule IDs agree.

export class DagWalker {
  // questionsData = parsed questions.json: { start, nodes }
  constructor(questionsData) {
    this.start = questionsData.start;
    this.nodes = questionsData.nodes;
    this.reset();
  }

  reset() {
    this.currentId = this.start;
    this.inputs = {};
    this.path = [];
    this.finished = false;
  }

  currentNode() {
    const node = this.nodes[this.currentId];
    if (!node) throw new Error(`Unknown node: ${this.currentId}`);
    return node;
  }

  isResult() {
    return this.currentNode().type === 'result';
  }

  // answer is boolean (true=yes, false=no). Throws if called on a result node.
  // Returns the new current node (which may itself be a result node).
  answer(yes) {
    const node = this.currentNode();
    if (node.type !== 'question') {
      throw new Error(`Cannot answer at non-question node: ${this.currentId}`);
    }
    this.path.push(this.currentId);
    this._recordAnswer(node, Boolean(yes));
    this.currentId = yes ? node.on_yes : node.on_no;
    if (this.isResult()) this.finished = true;
    return this.currentNode();
  }

  _recordAnswer(node, yes) {
    const fields = node.fields || [node.field];
    for (const f of fields) {
      if (!f) continue;
      this.inputs[f] = yes;
    }
  }

  // Returns the final result node along with the inputs bag and the
  // ordered list of question node IDs traversed. Caller should pass
  // `inputs` into engine.js to cross-verify.
  result() {
    if (!this.isResult()) return null;
    const node = this.currentNode();
    return {
      ruleId: node.rule_id,
      result: node.result,
      message: node.message,
      citation: node.citation,
      inputs: { ...this.inputs },
      path: this.path.slice(),
      node,
    };
  }
}
