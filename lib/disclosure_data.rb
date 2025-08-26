class DisclosureData
  attr_accessor :includes_fti, :recipient_type, :data_type, :purpose, :consent, 
                :contains_pii, :has_educational_interest, :legal_basis, 
                :research_purpose, :student_dependency_status, :other_99_31_exception

  def initialize(data = {})
    @includes_fti = data[:includes_fti] || false
    @recipient_type = data[:recipient_type]
    @data_type = data[:data_type]
    @purpose = data[:purpose]
    @consent = data[:consent] || {}
    @contains_pii = data[:contains_pii] || false
    @has_educational_interest = data[:has_educational_interest] || false
    @legal_basis = data[:legal_basis]
    @research_purpose = data[:research_purpose]
    @student_dependency_status = data[:student_dependency_status]
    @other_99_31_exception = data[:other_99_31_exception] || false
  end

  def [](key)
    case key
    when :includes_fti
      @includes_fti
    when :recipient_type
      @recipient_type
    when :data_type
      @data_type
    when :purpose
      @purpose
    when :consent
      @consent
    when :contains_pii
      @contains_pii
    when :has_educational_interest
      @has_educational_interest
    when :legal_basis
      @legal_basis
    when :research_purpose
      @research_purpose
    when :student_dependency_status
      @student_dependency_status
    when :other_99_31_exception
      @other_99_31_exception
    else
      false
    end
  end
end
