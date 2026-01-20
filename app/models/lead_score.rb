# == Schema Information
#
# Table name: lead_scores
#
#  id                 :bigint           not null, primary key
#  auto_qualified     :boolean          default(FALSE)
#  category           :integer          default("new_lead"), not null
#  last_analyzed_at   :datetime
#  qualification_data :jsonb            not null
#  score              :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  contact_id         :bigint           not null
#
# Indexes
#
#  index_lead_scores_on_account_id                 (account_id)
#  index_lead_scores_on_category                   (category)
#  index_lead_scores_on_contact_id                 (contact_id)
#  index_lead_scores_on_contact_id_and_account_id  (contact_id,account_id) UNIQUE
#  index_lead_scores_on_score                      (score)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#
class LeadScore < ApplicationRecord
  belongs_to :contact
  belongs_to :account

  # Category enum - represents lead stage in sales funnel
  enum category: {
    new_lead: 0,
    hot_lead: 1,
    payments: 2,
    existing_customer: 3
  }, _default: :new_lead

  # Validations
  validates :contact_id, presence: true, uniqueness: { scope: :account_id }
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :category, presence: true

  # Scopes
  scope :new_leads, -> { where(category: :new_lead) }
  scope :hot_leads, -> { where(category: :hot_lead) }
  scope :in_payments, -> { where(category: :payments) }
  scope :existing_customers, -> { where(category: :existing_customer) }
  scope :high_score, -> { where('score >= ?', 70) }
  scope :recently_analyzed, -> { where('last_analyzed_at > ?', 24.hours.ago) }

  # Category metadata
  CATEGORY_METADATA = {
    new_lead: {
      label: 'New Lead',
      icon: '🆕',
      color: 'blue',
      description: 'First-time contact, initial inquiry stage'
    },
    hot_lead: {
      label: 'Hot Lead',
      icon: '🔥',
      color: 'red',
      description: 'High engagement, strong purchase intent'
    },
    payments: {
      label: 'Payments',
      icon: '💰',
      color: 'green',
      description: 'Payment/negotiation stage'
    },
    existing_customer: {
      label: 'Existing Customer',
      icon: '⭐',
      color: 'gold',
      description: 'Previous purchase, repeat customer'
    }
  }.freeze

  # Get category metadata
  def category_metadata
    CATEGORY_METADATA[category.to_sym]
  end

  # Get category label
  def category_label
    category_metadata[:label]
  end

  # Get category icon
  def category_icon
    category_metadata[:icon]
  end

  # Get category color
  def category_color
    category_metadata[:color]
  end

  # Check if lead should be re-analyzed
  def needs_analysis?
    last_analyzed_at.nil? || last_analyzed_at < 24.hours.ago
  end

  # Update category and track transition
  def update_category!(new_category, notes: nil)
    old_category = category
    
    update!(
      category: new_category,
      qualification_data: qualification_data.merge(
        category_history: (qualification_data['category_history'] || []) + [{
          from: old_category,
          to: new_category,
          changed_at: Time.current.iso8601,
          notes: notes
        }]
      )
    )

    # Update contact additional_attributes
    contact.update!(
      additional_attributes: contact.additional_attributes.merge(
        'lead_category' => new_category,
        'last_category_change' => Time.current.iso8601
      )
    )
  end

  # Update score and potentially category
  def update_score!(new_score, analysis_data: {})
    old_score = score
    
    update!(
      score: new_score,
      last_analyzed_at: Time.current,
      qualification_data: qualification_data.merge(
        last_analysis: analysis_data,
        score_history: (qualification_data['score_history'] || []) + [{
          score: new_score,
          analyzed_at: Time.current.iso8601
        }]
      )
    )

    # Update contact additional_attributes
    contact.update!(
      additional_attributes: contact.additional_attributes.merge(
        'lead_score' => new_score,
        'qualification_notes' => analysis_data['notes']
      )
    )

    # Auto-update category based on score and analysis
    determine_category_from_analysis(analysis_data) if auto_qualified
  end

  private

  def determine_category_from_analysis(analysis_data)
    # This will be called by the AI service
    # Category determination logic is in LeadQualificationService
  end
end
