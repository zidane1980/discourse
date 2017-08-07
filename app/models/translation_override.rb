require 'js_locale_helper'
require "i18n/i18n_interpolation_keys_finder"

class TranslationOverride < ActiveRecord::Base
  validates_uniqueness_of :translation_key, scope: :locale
  validates_presence_of :locale, :translation_key, :value

  validate :check_interpolation_keys

  def self.upsert!(locale, key, value)
    params = { locale: locale, translation_key: key }

    data = { value: value }
    if key.end_with?('_MF')
      data[:compiled_js] = JsLocaleHelper.compile_message_format(locale, value)
    end

    translation_override = find_or_initialize_by(params)
    params.merge!(data) if translation_override.new_record?
    i18n_changed if translation_override.update(data)
    translation_override
  end

  def self.revert!(locale, *keys)
    TranslationOverride.where(locale: locale, translation_key: keys).delete_all
    i18n_changed
  end

  private

    def self.i18n_changed
      I18n.reload!
      MessageBus.publish('/i18n-flush', refresh: true)
    end

    def check_interpolation_keys
      original_text = I18n.overrides_disabled do
        I18n.backend.send(:lookup, self.locale, self.translation_key)
      end

      if original_text
        original_interpolation_keys = I18nInterpolationKeysFinder.find(original_text)
        new_interpolation_keys = I18nInterpolationKeysFinder.find(value)
        missing_keys = (original_interpolation_keys - new_interpolation_keys)

        if missing_keys.present?
          self.errors.add(:base, I18n.t(
            'activerecord.errors.models.translation_overrides.attributes.value.missing_interpolation_keys',
            keys: missing_keys.join(', ')
          ))

          return false
        end
      end
    end

end

# == Schema Information
#
# Table name: translation_overrides
#
#  id              :integer          not null, primary key
#  locale          :string           not null
#  translation_key :string           not null
#  value           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  compiled_js     :text
#
# Indexes
#
#  index_translation_overrides_on_locale_and_translation_key  (locale,translation_key) UNIQUE
#
