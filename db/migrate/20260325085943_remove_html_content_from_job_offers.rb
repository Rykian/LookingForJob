class RemoveHtmlContentFromJobOffers < ActiveRecord::Migration[8.1]
  class MigrationJobOffer < ApplicationRecord
    self.table_name = "job_offers"

    has_one_attached :html_file
  end

  def up
    say_with_time "Migrating job_offers.html_content to ActiveStorage html_file" do
      MigrationJobOffer.where.not(html_content: [nil, ""]).find_each do |offer|
        next if offer.html_file.attached?

        offer.html_file.attach(
          io: StringIO.new(offer.html_content),
          filename: "#{offer.url_hash.presence || offer.id}.html",
          content_type: "text/html"
        )
      end
    end

    remove_column :job_offers, :html_content, :text
  end

  def down
    add_column :job_offers, :html_content, :text

    say_with_time "Restoring html_content from ActiveStorage html_file" do
      MigrationJobOffer.reset_column_information

      MigrationJobOffer.find_each do |offer|
        next unless offer.html_file.attached?

        offer.update_columns(html_content: offer.html_file.download)
      end
    end
  end
end
