// quiz.js — NASFAA disclosure quiz state machine.
//
// Mirrors lib/nasfaa/quiz.rb.  Two modes:
//
//   Scenario mode (default): shuffles the 24 named scenarios from
//     scenarios.json and presents description + inputs.  The expected
//     result + rule_id + citation come from the scenario itself.
//
//   Random mode (?mode=random[&count=N]): generates N (default 10)
//     boolean DisclosureData bags and evaluates each with RuleEngine.
//
// In both modes, permit_with_caution and permit_with_scope count as
// "permit" when the user answers permit.
//
// No DOM dependencies — app.js drives presentation.

(function (root) {
  'use strict';

  const RANDOM_QUESTION_COUNT_DEFAULT = 10;

  function shuffle(arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  function quizQuestionFromScenario(scenario) {
    return {
      description: scenario.description || null,
      name: scenario.name || null,
      inputs: scenario.inputs || {},
      expectedResult: scenario.expected.result,
      ruleId: scenario.expected.rule_id,
      citation: scenario.citation || null,
    };
  }

  function buildRandomQuestion(engine, fields) {
    // Pick 1..5 fields and set them to true.  Mirrors quiz.rb#build_random_question.
    const count = 1 + Math.floor(Math.random() * 5);
    const pool = fields.slice();
    // partial Fisher-Yates to pick `count` unique fields
    for (let i = 0; i < count && i < pool.length; i++) {
      const j = i + Math.floor(Math.random() * (pool.length - i));
      [pool[i], pool[j]] = [pool[j], pool[i]];
    }
    const inputs = {};
    for (let i = 0; i < count; i++) {
      inputs[pool[i]] = true;
    }
    const trace = engine.evaluate(inputs);
    return {
      description: null,
      name: null,
      inputs,
      expectedResult: trace ? trace.result : 'deny',
      ruleId: trace ? trace.ruleId : '(no rule matched)',
      citation: null,
    };
  }

  // Build the question list according to mode.
  function buildQuestions({ mode, scenarios, engine, fields, count }) {
    if (mode === 'random') {
      const n = (typeof count === 'number' && count > 0) ? count : RANDOM_QUESTION_COUNT_DEFAULT;
      const questions = [];
      for (let i = 0; i < n; i++) {
        questions.push(buildRandomQuestion(engine, fields));
      }
      return questions;
    }
    return shuffle(scenarios.map(quizQuestionFromScenario));
  }

  // Compare a user answer (:permit / :deny) to a question's expected result.
  // permit_with_scope and permit_with_caution count as :permit.
  function isCorrect(answer, expected) {
    const expectedSimple =
      (expected === 'permit' || expected === 'permit_with_scope' || expected === 'permit_with_caution')
        ? 'permit'
        : 'deny';
    return answer === expectedSimple;
  }

  // Pure state container for the quiz.  App layer pushes answers in and
  // reads current/score back out.
  class QuizState {
    constructor(questions) {
      this.questions = questions;
      this.index = 0;
      this.correct = 0;
      this.total = 0;
      this.finished = questions.length === 0;
      this.lastAnswer = null;       // 'permit' | 'deny' | null
      this.lastWasCorrect = null;   // true | false | null
      this.revealing = false;       // true between answer and next-question
    }

    current() {
      return this.finished ? null : this.questions[this.index];
    }

    questionNumber() {
      return this.index + 1;
    }

    questionCount() {
      return this.questions.length;
    }

    // Apply a permit/deny answer to the current question.  Returns the
    // current question (now revealed) so the caller can display it.
    answer(choice) {
      if (this.finished || this.revealing) return null;
      const q = this.current();
      const correct = isCorrect(choice, q.expectedResult);
      this.lastAnswer = choice;
      this.lastWasCorrect = correct;
      if (correct) this.correct += 1;
      this.total = this.index + 1;
      this.revealing = true;
      return q;
    }

    // Move past the reveal to the next question (or finish).
    advance() {
      if (!this.revealing) return;
      this.revealing = false;
      this.index += 1;
      if (this.index >= this.questions.length) {
        this.finished = true;
      }
    }

    // Player gave up.  Marks finished without scoring the current question.
    quit() {
      this.finished = true;
      this.revealing = false;
    }

    percent() {
      if (this.total === 0) return 0;
      return Math.round((this.correct / this.total) * 100);
    }
  }

  const Quiz = {
    RANDOM_QUESTION_COUNT_DEFAULT,
    shuffle,
    quizQuestionFromScenario,
    buildRandomQuestion,
    buildQuestions,
    isCorrect,
    QuizState,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = Quiz;
  } else {
    root.NasfaaQuiz = Quiz;
  }
})(typeof self !== 'undefined' ? self : this);
