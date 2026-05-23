// dag.js — DAG walker for nasfaa_questions.yml
//
// Plain script; attaches `window.Nasfaa.DagWalker`.

(function (global) {
  'use strict';

  class DagWalker {
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

  global.Nasfaa = global.Nasfaa || {};
  global.Nasfaa.DagWalker = DagWalker;
})(typeof window !== 'undefined' ? window : globalThis);
