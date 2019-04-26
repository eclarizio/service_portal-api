describe ApprovalRequest, :type => :model do
  let(:tenant) { create(:tenant, :external_tenant => default_user_hash['identity']['account_number']) }
  let(:order_item1) { create(:order_item, :tenant_id => tenant.id, :portfolio_item_id => 1, :order_id => 1) }
  let(:order_item2) { create(:order_item, :tenant_id => tenant.id, :portfolio_item_id => 1, :order_id => 1) }
  let!(:approval_request1) { create(:approval_request, :order_item_id => order_item1.id) }
  let!(:approval_request2) { create(:approval_request, :order_item_id => order_item2.id) }

  around do |example|
    ManageIQ::API::Common::Request.with_request(default_request) { example.call }
  end

  context "by_owner" do
    let(:results) { ApprovalRequest.by_owner }

    before do
      order_item2.update!(:owner => "not_jdoe")
    end

    it "only has one result" do
      expect(results.size).to eq 1
    end

    it "filters by the owner" do
      expect(results.first.owner).to eq "jdoe"
    end
  end
end
