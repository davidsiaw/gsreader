# frozen_string_literal: true

RSpec.describe GsReader::Cell do
  def make_cell(effective_format: nil, effective_value: nil, data_validation: nil, formatted_value: nil)
    S::CellData.new(
      effective_format: effective_format,
      effective_value: effective_value,
      data_validation: data_validation,
      formatted_value: formatted_value
    )
  end

  describe '#background_color' do
    it 'returns nil when there is no format' do
      expect(described_class.new(make_cell).background_color).to be_nil
    end

    it 'converts an rgb_color from background_color_style to hex' do
      style = S::ColorStyle.new(rgb_color: S::Color.new(red: 1.0, green: 0.0, blue: 0.0))
      fmt = S::CellFormat.new(background_color_style: style)
      cell = described_class.new(make_cell(effective_format: fmt))
      expect(cell.background_color).to eq('#ff0000')
    end

    it 'falls back to the legacy background_color field' do
      fmt = S::CellFormat.new(background_color: S::Color.new(red: 0.0, green: 1.0, blue: 0.0))
      cell = described_class.new(make_cell(effective_format: fmt))
      expect(cell.background_color).to eq('#00ff00')
    end

    it 'treats missing channels as 0' do
      fmt = S::CellFormat.new(background_color: S::Color.new(blue: 1.0))
      cell = described_class.new(make_cell(effective_format: fmt))
      expect(cell.background_color).to eq('#0000ff')
    end

    it 'handles edge case: white background color' do
      style = S::ColorStyle.new(rgb_color: S::Color.new(red: 1.0, green: 1.0, blue: 1.0))
      fmt = S::CellFormat.new(background_color_style: style)
      cell = described_class.new(make_cell(effective_format: fmt))
      expect(cell.background_color).to eq('#ffffff')
    end
  end

  describe '#checkbox? / #checked?' do
    let(:bool_validation) do
      S::DataValidationRule.new(condition: S::BooleanCondition.new(type: 'BOOLEAN'))
    end

    it 'is a checkbox when data validation is BOOLEAN' do
      cell = described_class.new(make_cell(data_validation: bool_validation))
      expect(cell.checkbox?).to be true
    end

    it 'is not a checkbox without data validation' do
      expect(described_class.new(make_cell).checkbox?).to be false
    end

    it 'is not a checkbox for non-BOOLEAN validation' do
      rule = S::DataValidationRule.new(condition: S::BooleanCondition.new(type: 'NUMBER_GREATER'))
      cell = described_class.new(make_cell(data_validation: rule))
      expect(cell.checkbox?).to be false
    end

    it 'is checked when the boolean checkbox value is true' do
      cell = described_class.new(make_cell(
                                   data_validation: bool_validation,
                                   effective_value: S::ExtendedValue.new(bool_value: true)
                                 ))
      expect(cell.checked?).to be true
    end

    it 'is not checked when the boolean checkbox value is false' do
      cell = described_class.new(make_cell(
                                   data_validation: bool_validation,
                                   effective_value: S::ExtendedValue.new(bool_value: false)
                                 ))
      expect(cell.checked?).to be false
    end

    it 'is not checked when the cell is not a checkbox at all' do
      cell = described_class.new(make_cell(effective_value: S::ExtendedValue.new(bool_value: true)))
      expect(cell.checked?).to be false
    end

    it 'handles edge case: checkbox with nil value' do
      cell = described_class.new(make_cell(data_validation: bool_validation))
      expect(cell.checked?).to be false
    end
  end

  describe '#value' do
    it 'returns nil for empty cells' do
      expect(described_class.new(make_cell).value).to be_nil
    end

    it 'returns string values' do
      cell = described_class.new(make_cell(effective_value: S::ExtendedValue.new(string_value: 'hi')))
      expect(cell.value).to eq('hi')
    end

    it 'returns number values' do
      cell = described_class.new(make_cell(effective_value: S::ExtendedValue.new(number_value: 42)))
      expect(cell.value).to eq(42)
    end

    it 'returns boolean values' do
      cell = described_class.new(make_cell(effective_value: S::ExtendedValue.new(bool_value: false)))
      expect(cell.value).to be false
    end

    it 'returns formula values' do
      cell = described_class.new(make_cell(effective_value: S::ExtendedValue.new(formula_value: '=SUM(A1:A2)')))
      expect(cell.value).to eq('=SUM(A1:A2)')
    end
  end

  describe '#formatted_value' do
    it 'returns the cell\'s display string' do
      cell = described_class.new(make_cell(formatted_value: '$1,234'))
      expect(cell.formatted_value).to eq('$1,234')
    end
  end

  describe 'a totally empty wrapper' do
    it 'returns nil for background_color' do
      expect(described_class.new(nil).background_color).to be_nil
    end

    it 'returns false for checkbox?' do
      expect(described_class.new(nil).checkbox?).to be false
    end

    it 'returns false for checked?' do
      expect(described_class.new(nil).checked?).to be false
    end

    it 'returns nil for value' do
      expect(described_class.new(nil).value).to be_nil
    end

    it 'returns nil for formatted_value' do
      expect(described_class.new(nil).formatted_value).to be_nil
    end
  end

  describe 'edge cases' do
    it 'handles malformed data validation' do
      bad_validation = S::DataValidationRule.new(condition: nil)
      cell = described_class.new(make_cell(data_validation: bad_validation))
      expect(cell.checkbox?).to be false
    end
  end
end
