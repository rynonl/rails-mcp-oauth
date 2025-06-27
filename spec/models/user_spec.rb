require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:workos_id) }
    it { should validate_uniqueness_of(:workos_id) }
    it { should validate_presence_of(:email) }
    it { should allow_value('user@example.com').for(:email) }
    it { should_not allow_value('invalid-email').for(:email) }
  end

  describe 'associations' do
    it { should have_many(:oauth_sessions).dependent(:destroy) }
  end

  describe '#full_name' do
    context 'when both first and last name are present' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }
      
      it 'returns the full name' do
        expect(user.full_name).to eq('John Doe')
      end
    end

    context 'when only first name is present' do
      let(:user) { build(:user, first_name: 'John', last_name: nil) }
      
      it 'returns just the first name' do
        expect(user.full_name).to eq('John')
      end
    end

    context 'when names are blank' do
      let(:user) { build(:user, first_name: '', last_name: '') }
      
      it 'returns empty string' do
        expect(user.full_name).to eq('')
      end
    end
  end

  describe '#display_name' do
    context 'when full name is present' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
      
      it 'returns the full name' do
        expect(user.display_name).to eq('John Doe')
      end
    end

    context 'when full name is blank' do
      let(:user) { build(:user, first_name: '', last_name: '', email: 'john@example.com') }
      
      it 'returns the email' do
        expect(user.display_name).to eq('john@example.com')
      end
    end
  end

  describe '.from_workos_user' do
    let(:workos_user) do
      double('WorkOS::User',
        id: 'workos_123',
        email: 'test@example.com',
        first_name: 'Test',
        last_name: 'User',
        profile_picture_url: 'https://example.com/avatar.jpg'
      )
    end
    let(:organization_id) { 'org_123' }

    context 'when user does not exist' do
      it 'creates a new user' do
        expect {
          User.from_workos_user(workos_user, organization_id)
        }.to change(User, :count).by(1)
        
        user = User.last
        expect(user.workos_id).to eq('workos_123')
        expect(user.email).to eq('test@example.com')
        expect(user.first_name).to eq('Test')
        expect(user.last_name).to eq('User')
        expect(user.profile_picture_url).to eq('https://example.com/avatar.jpg')
        expect(user.organization_id).to eq('org_123')
      end
    end

    context 'when user already exists' do
      let!(:existing_user) { create(:user, workos_id: 'workos_123') }

      it 'returns the existing user without creating a new one' do
        expect {
          result = User.from_workos_user(workos_user, organization_id)
          expect(result).to eq(existing_user)
        }.not_to change(User, :count)
      end
    end
  end
end
