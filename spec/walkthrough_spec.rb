# frozen_string_literal: true

require 'rspec'
require 'stringio'
require_relative 'spec_helper'

RSpec.describe Nasfaa::Walkthrough do
  let(:questions_path) { Nasfaa::Walkthrough::QUESTIONS_PATH }
  let(:dag) { YAML.safe_load_file(questions_path) }
  let(:engine) { Nasfaa::RuleEngine.new }

  # Helper: build a Walkthrough with scripted yes/no input
  def run_walkthrough(*responses)
    input = StringIO.new("#{responses.join("\n")}\n")
    output = StringIO.new
    walkthrough = described_class.new(input: input, output: output, questions_path: questions_path)
    trace = walkthrough.run
    [trace, output.string, walkthrough]
  end

  # ------------------------------------------------------------------
  # DAG structure validation
  # ------------------------------------------------------------------
  describe 'DAG structure' do
    let(:nodes) { dag['nodes'] }

    it 'has a valid start node' do
      expect(nodes).to have_key(dag['start'])
    end

    it 'every question node references valid on_yes and on_no targets' do
      nodes.each do |id, node|
        next unless node['type'] == 'question'

        expect(nodes).to have_key(node['on_yes']),
                         "#{id}.on_yes references unknown node #{node['on_yes']}"
        expect(nodes).to have_key(node['on_no']),
                         "#{id}.on_no references unknown node #{node['on_no']}"
      end
    end

    it 'every question node has a field or fields' do
      nodes.each do |id, node|
        next unless node['type'] == 'question'

        has_field = node.key?('field') || node.key?('fields')
        expect(has_field).to be(true), "#{id} has neither field nor fields"
      end
    end

    it 'every result node has rule_id, result, message, and citation' do
      nodes.each do |id, node|
        next unless node['type'] == 'result'

        %w[rule_id result message citation].each do |key|
          expect(node).to have_key(key), "#{id} missing #{key}"
        end
      end
    end

    it 'has exactly 23 question nodes and 23 result nodes' do
      questions = nodes.count { |_, n| n['type'] == 'question' }
      results = nodes.count { |_, n| n['type'] == 'result' }
      expect(questions).to eq(23)
      expect(results).to eq(23)
    end

    it 'every result node rule_id matches a rule in nasfaa_rules.yml' do
      rule_ids = engine.rules.map { |r| r['id'] }
      nodes.each do |id, node|
        next unless node['type'] == 'result'

        expect(rule_ids).to include(node['rule_id']),
                            "#{id} references unknown rule #{node['rule_id']}"
      end
    end
  end

  # ------------------------------------------------------------------
  # FTI branch — all 5 terminal nodes
  # ------------------------------------------------------------------
  describe 'FTI branch' do
    it 'permits disclosure to student (FTI_R1)' do
      trace, output, = run_walkthrough('yes', 'yes')
      expect(trace.rule_id).to eq('FTI_R1_student')
      expect(trace.result).to eq(:permit)
      expect(output).to include('PERMIT')
      expect(output).to include('IRC §6103(l)(13)')
    end

    it 'permits FTI for aid admin with school official LEI (FTI_R2)' do
      trace, = run_walkthrough('yes', 'no', 'yes', 'yes')
      expect(trace.rule_id).to eq('FTI_R2_aid_admin_school_official')
      expect(trace.result).to eq(:permit)
    end

    it 'denies FTI for aid admin without LEI (FTI_R2b)' do
      trace, output, = run_walkthrough('yes', 'no', 'yes', 'no')
      expect(trace.rule_id).to eq('FTI_R2b_aid_admin_deny')
      expect(trace.result).to eq(:deny)
      expect(output).to include('DENY')
    end

    it 'permits FTI to scholarship org with consent (FTI_R3)' do
      trace, = run_walkthrough('yes', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FTI_R3_scholarship_with_consent')
      expect(trace.result).to eq(:permit)
    end

    it 'denies FTI by default (FTI_DENY)' do
      trace, = run_walkthrough('yes', 'no', 'no', 'no')
      expect(trace.rule_id).to eq('FTI_DENY_default')
      expect(trace.result).to eq(:deny)
    end
  end

  # ------------------------------------------------------------------
  # Non-FTI / FAFSA branch — all 7 terminal nodes
  # ------------------------------------------------------------------
  describe 'FAFSA branch' do
    it 'permits disclosure to student (FAFSA_R1)' do
      trace, = run_walkthrough('no', 'yes')
      expect(trace.rule_id).to eq('FAFSA_R1_to_student')
      expect(trace.result).to eq(:permit)
    end

    it 'permits with scope to contributor (FAFSA_R2)' do
      trace, = run_walkthrough('no', 'no', 'yes', 'yes')
      expect(trace.rule_id).to eq('FAFSA_R2_to_contributor_scope_limited')
      expect(trace.result).to eq(:permit_with_scope)
    end

    it 'permits FAFSA for aid admin (FAFSA_R3)' do
      trace, = run_walkthrough('no', 'no', 'yes', 'no', 'yes')
      expect(trace.rule_id).to eq('FAFSA_R3_used_for_aid_admin')
      expect(trace.result).to eq(:permit)
    end

    it 'permits FAFSA to scholarship org with consent (FAFSA_R4)' do
      trace, = run_walkthrough('no', 'no', 'yes', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FAFSA_R4_scholarship_with_consent')
      expect(trace.result).to eq(:permit)
    end

    it 'permits FAFSA for institutional research (FAFSA_R5)' do
      trace, = run_walkthrough('no', 'no', 'yes', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FAFSA_R5_institutional_research_promote_attendance')
      expect(trace.result).to eq(:permit)
    end

    it 'permits FAFSA with HEA written consent (FAFSA_R6)' do
      trace, = run_walkthrough('no', 'no', 'yes', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FAFSA_R6_HEA_written_consent')
      expect(trace.result).to eq(:permit)
    end

    it 'permits FAFSA without PII (FAFSA_R7)' do
      trace, = run_walkthrough('no', 'no', 'yes', 'no', 'no', 'no', 'no', 'no', 'no')
      expect(trace.rule_id).to eq('FAFSA_R7_no_pii')
      expect(trace.result).to eq(:permit)
    end
  end

  # ------------------------------------------------------------------
  # FERPA branch — all 11 terminal nodes
  # (reached via non-FAFSA data OR FAFSA data with PII)
  # ------------------------------------------------------------------
  describe 'FERPA branch (via non-FAFSA data)' do
    # non-FTI → not student → not FAFSA → FERPA consent
    it 'permits with FERPA written consent (FERPA_R0)' do
      trace, = run_walkthrough('no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R0_written_consent')
      expect(trace.result).to eq(:permit)
    end

    it 'permits directory info (FERPA_R1)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R1_directory_info')
      expect(trace.result).to eq(:permit)
    end

    it 'permits school official with LEI (FERPA_R2)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R2_school_official_LEI')
      expect(trace.result).to eq(:permit)
    end

    it 'permits with caution for judicial order (FERPA_R3)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R3_judicial_or_finaid_related')
      expect(trace.result).to eq(:permit_with_caution)
    end

    it 'permits for transfer/enrollment (FERPA_R4)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R4_other_school_enrollment')
      expect(trace.result).to eq(:permit)
    end

    it 'permits for authorized representatives (FERPA_R5)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R5_authorized_representatives')
      expect(trace.result).to eq(:permit)
    end

    it 'permits for research organizations (FERPA_R6)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R6_research_org_predictive_tests_admin_aid_improve_instruction')
      expect(trace.result).to eq(:permit)
    end

    it 'permits for accrediting agency (FERPA_R7)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R7_accrediting_agency')
      expect(trace.result).to eq(:permit)
    end

    it 'permits for parent of dependent student (FERPA_R8)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R8_parent_of_dependent_student')
      expect(trace.result).to eq(:permit)
    end

    it 'permits for other 99.31 exception (FERPA_R9)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'yes')
      expect(trace.rule_id).to eq('FERPA_R9_otherwise_permitted_99_31')
      expect(trace.result).to eq(:permit)
    end

    it 'denies when no exception applies (NONFTI_DENY)' do
      trace, = run_walkthrough('no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no', 'no')
      expect(trace.rule_id).to eq('NONFTI_DENY_default')
      expect(trace.result).to eq(:deny)
    end
  end

  describe 'FERPA branch (via FAFSA data with PII)' do
    # non-FTI → not student → FAFSA → all FAFSA-specific no → has PII → FERPA consent
    it 'routes FAFSA+PII into FERPA consent check' do
      # no(FTI) → no(student) → yes(FAFSA) → no(contributor) → no(aid admin) →
      # no(scholarship) → no(research) → no(HEA consent) → yes(PII) → yes(FERPA consent)
      trace, = run_walkthrough('no', 'no', 'yes', 'no', 'no', 'no', 'no', 'no', 'yes', 'yes')
      expect(trace.rule_id).to eq('FERPA_R0_written_consent')
    end

    it 'reaches default deny via FAFSA+PII path' do
      answers = %w[no no yes no no no no no yes] + Array.new(10, 'no')
      trace, = run_walkthrough(*answers)
      expect(trace.rule_id).to eq('NONFTI_DENY_default')
      expect(trace.result).to eq(:deny)
    end
  end

  # ------------------------------------------------------------------
  # Path tracking
  # ------------------------------------------------------------------
  describe 'path tracking' do
    it 'records only question nodes in the path' do
      trace, = run_walkthrough('yes', 'yes')
      expect(trace.path).to eq(%w[fti_check fti_to_student])
    end

    it 'records the full path for deep traversals' do
      trace, = run_walkthrough('yes', 'no', 'no', 'no')
      expect(trace.path).to eq(%w[fti_check fti_to_student fti_aid_admin fti_scholarship])
    end

    it 'records the longest non-FTI path correctly' do
      answers = Array.new(13, 'no')
      trace, = run_walkthrough(*answers)
      expected_path = %w[
        fti_check nonfti_to_student nonfti_fafsa_check ferpa_consent
        ferpa_directory ferpa_school_official ferpa_judicial ferpa_transfer
        ferpa_authorized_rep ferpa_research_org ferpa_accreditor ferpa_parent
        ferpa_otherwise
      ]
      expect(trace.path).to eq(expected_path)
    end
  end

  # ------------------------------------------------------------------
  # Answer collection and DisclosureData
  # ------------------------------------------------------------------
  describe 'answer collection' do
    it 'collects answers as symbol-keyed hash' do
      _, _, walkthrough = run_walkthrough('yes', 'yes')
      expect(walkthrough.answers).to eq(
        includes_fti: true,
        disclosure_to_student: true
      )
    end

    it 'handles compound field questions' do
      # FTI path to scholarship: yes(FTI), no(student), no(aid admin), yes(scholarship+consent)
      _, _, walkthrough = run_walkthrough('yes', 'no', 'no', 'yes')
      expect(walkthrough.answers[:disclosure_to_scholarship_org]).to be true
      expect(walkthrough.answers[:explicit_written_consent]).to be true
    end

    it 'builds a valid DisclosureData from collected answers' do
      _, _, walkthrough = run_walkthrough('yes', 'no', 'yes', 'yes')
      data = walkthrough.to_disclosure_data
      expect(data).to be_a(Nasfaa::DisclosureData)
      expect(data.includes_fti?).to be true
      expect(data.disclosure_to_student?).to be false
      expect(data.used_for_aid_admin?).to be true
      expect(data.to_school_official_legitimate_interest?).to be true
    end
  end

  # ------------------------------------------------------------------
  # Cross-verification with RuleEngine
  # ------------------------------------------------------------------
  describe 'cross-verification with RuleEngine' do
    # Every DAG result node should agree with the RuleEngine evaluation
    # of the same answers. We test all 23 terminal paths.
    paths = {
      'FTI_R1_student' => %w[yes yes],
      'FTI_R2_aid_admin_school_official' => %w[yes no yes yes],
      'FTI_R2b_aid_admin_deny' => %w[yes no yes no],
      'FTI_R3_scholarship_with_consent' => %w[yes no no yes],
      'FTI_DENY_default' => %w[yes no no no],
      'FAFSA_R1_to_student' => %w[no yes],
      'FAFSA_R2_to_contributor_scope_limited' => %w[no no yes yes],
      'FAFSA_R3_used_for_aid_admin' => %w[no no yes no yes],
      'FAFSA_R4_scholarship_with_consent' => %w[no no yes no no yes],
      'FAFSA_R5_institutional_research_promote_attendance' => %w[no no yes no no no yes],
      'FAFSA_R6_HEA_written_consent' => %w[no no yes no no no no yes],
      'FAFSA_R7_no_pii' => %w[no no yes no no no no no no],
      'FERPA_R0_written_consent' => %w[no no no yes],
      'FERPA_R1_directory_info' => %w[no no no no yes],
      'FERPA_R2_school_official_LEI' => %w[no no no no no yes],
      'FERPA_R3_judicial_or_finaid_related' => %w[no no no no no no yes],
      'FERPA_R4_other_school_enrollment' => %w[no no no no no no no yes],
      'FERPA_R5_authorized_representatives' => %w[no no no no no no no no yes],
      'FERPA_R6_research_org_predictive_tests_admin_aid_improve_instruction' => %w[no no no no no no no no no yes],
      'FERPA_R7_accrediting_agency' => %w[no no no no no no no no no no yes],
      'FERPA_R8_parent_of_dependent_student' => %w[no no no no no no no no no no no yes],
      'FERPA_R9_otherwise_permitted_99_31' => %w[no no no no no no no no no no no no yes],
      'NONFTI_DENY_default' => %w[no no no no no no no no no no no no no]
    }

    paths.each do |expected_rule_id, responses|
      it "DAG and RuleEngine agree on #{expected_rule_id}" do
        trace, _, walkthrough = run_walkthrough(*responses)
        expect(trace.rule_id).to eq(expected_rule_id)

        data = walkthrough.to_disclosure_data
        engine_trace = engine.evaluate(data)
        expect(engine_trace.rule_id).to eq(expected_rule_id),
                                        "DAG returned #{expected_rule_id} but RuleEngine returned #{engine_trace.rule_id}"
      end
    end
  end

  # ------------------------------------------------------------------
  # Output formatting
  # ------------------------------------------------------------------
  describe 'output formatting' do
    it 'displays box number and question text' do
      _, output, = run_walkthrough('yes', 'yes')
      expect(output).to include('Box 1 (both pages)')
      expect(output).to include('Federal Tax Information')
    end

    it 'displays help text when available' do
      _, output, = run_walkthrough('yes', 'yes')
      expect(output).to include('IRS Data Retrieval Tool')
    end

    it 'displays result block with rule_id, citation, and path' do
      _, output, = run_walkthrough('yes', 'yes')
      expect(output).to include('FTI_R1_student')
      expect(output).to include('IRC §6103(l)(13)')
      expect(output).to include('fti_check -> fti_to_student')
    end
  end

  # ------------------------------------------------------------------
  # Input handling
  # ------------------------------------------------------------------
  describe 'input handling' do
    it 'accepts abbreviated input (y/n)' do
      trace, = run_walkthrough('y', 'n', 'y', 'y')
      expect(trace.rule_id).to eq('FTI_R2_aid_admin_school_official')
    end

    it 'accepts mixed-case input' do
      trace, = run_walkthrough('YES', 'Yes')
      expect(trace.rule_id).to eq('FTI_R1_student')
    end

    it 'reprompts on invalid input then accepts valid answer' do
      input = StringIO.new("maybe\nyes\nyes\n")
      output = StringIO.new
      walkthrough = described_class.new(input: input, output: output)
      trace = walkthrough.run
      expect(trace.rule_id).to eq('FTI_R1_student')
      expect(output.string).to include('Please answer yes or no')
    end

    it 'raises on unexpected end of input' do
      input = StringIO.new("yes\n")
      output = StringIO.new
      walkthrough = described_class.new(input: input, output: output)
      expect { walkthrough.run }.to raise_error(RuntimeError, 'Unexpected end of input')
    end
  end
end
