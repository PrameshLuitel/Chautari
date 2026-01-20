# frozen_string_literal: true

class Ai::AutoLabelJob < ApplicationJob
  queue_as :low

  def perform(contact_id, account_id)
    contact = Contact.find_by(id: contact_id)
    account = Account.find_by(id: account_id)

    return unless contact && account

    Ai::AutoLabelService.new(contact: contact, account: account).perform
  end
end
