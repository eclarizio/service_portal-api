describe Api::V1x1::Catalog::PortfolioItemOrderable, :type => [:service, :current_forwardable, :inventory, :sources] do
  let(:subject) { described_class.new(portfolio_item) }
  let(:service_offering_ref) { '998' }
  let(:service_offering_source_ref) { '999' }
  let(:archived_at) { nil }
  let(:availability_status) { 'available' }
  let(:survey_changed) { false }
  let(:portfolio_item) do
    create(:portfolio_item,
           :service_offering_ref        => service_offering_ref,
           :service_offering_source_ref => service_offering_source_ref)
  end
  let(:service_plans) { [] }

  let(:service_offering_response) do
    CatalogInventoryApiClient::ServiceOffering.new(:archived_at => archived_at)
  end

  let(:source_response) do
    CatalogInventoryApiClient::Source.new(:info => 'the platform', :availability_status => availability_status)
  end
  let(:source_api) { instance_double(CatalogInventoryApiClient::SourceApi) }
  let(:service_offering_api) { instance_double(CatalogInventoryApiClient::ServiceOfferingApi) }

  describe "#process" do
    context "no errors" do
      before do
        allow(CatalogInventory::Service).to receive(:call).with(CatalogInventoryApiClient::SourceApi).and_yield(source_api)
        allow(source_api).to receive(:show_source).and_return(source_response)
        allow(CatalogInventory::Service).to receive(:call).with(CatalogInventoryApiClient::ServiceOfferingApi).and_yield(service_offering_api)
        allow(service_offering_api).to receive(:show_service_offering).and_return(service_offering_response)

        allow(::Catalog::SurveyCompare).to receive(:any_changed?).with(service_plans).and_return(survey_changed)
      end

      context "when the nothing has changed without service plans" do
        it "returns true" do
          expect(subject.process.result).to be(true)
        end
      end

      context "when the nothing has changed with service plans" do
        let(:service_plans) { [create(:service_plan, :portfolio_item => portfolio_item)] }
        it "returns true" do
          expect(subject.process.result).to be(true)
        end
      end

      context "when the source is not available" do
        let(:availability_status) { 'not available' }
        it "returns false" do
          expect(subject.process.result).to be(false)
        end
      end

      context "when the survey has changed" do
        let(:survey_changed) { true }
        it "returns false" do
          expect(subject.process.result).to be(false)
        end
      end

      context "when the service offering has been archived" do
        let(:archived_at) { Time.now }
        it "returns false" do
          expect(subject.process.result).to be(false)
        end
      end
    end

    context "with errors from inventory" do
      before do
        allow(CatalogInventory::Service).to receive(:call).with(CatalogInventoryApiClient::SourceApi).and_yield(source_api)
        allow(source_api).to receive(:show_source).and_return(source_response)
        allow(CatalogInventory::Service).to receive(:call).with(CatalogInventoryApiClient::ServiceOfferingApi).and_raise(Catalog::CatalogInventoryError.new("Kaboom"))
      end

      context "when the service offering cannot be retrieved" do
        it "returns false" do
          obj = subject.process
          expect(obj.result).to be(false)
          expect(obj.messages[0]).to match(/CatalogInventoryApiClient::ServiceOfferingApi:show_service_offering could not retrieve for #{service_offering_ref}/)
        end
      end
    end

    context "with errors from source" do
      before do
        allow(CatalogInventory::Service).to receive(:call).with(CatalogInventoryApiClient::SourceApi)
                                                          .and_raise(Catalog::SourcesError.new("Kaboom"))
        allow(CatalogInventory::Service).to receive(:call).with(CatalogInventoryApiClient::ServiceOfferingApi).and_yield(service_offering_api)
        allow(service_offering_api).to receive(:show_service_offering).and_return(service_offering_response)
      end

      context "when the source cannot be retrieved" do
        it "returns false" do
          obj = subject.process
          expect(obj.result).to be(false)
          expect(obj.messages[0]).to match(/CatalogInventoryApiClient::SourceApi:show_source could not retrieve for #{service_offering_source_ref}/)
        end
      end
    end
  end
end
