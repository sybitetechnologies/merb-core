require File.join(File.dirname(__FILE__), "spec_helper")

describe Merb::Controller, " callable actions" do
  
  before do
    Merb.push_path(:layout, File.dirname(__FILE__) / "controllers" / "views" / "layouts")    
    Merb::Router.prepare do |r|
      r.default_routes
    end
  end
  
  it "should dispatch to callable actions" do
    dispatch_to(Merb::Test::Fixtures::Controllers::Base, :index).body.should == "index"
  end

  it "should not dispatch to hidden actions" do
    calling { dispatch_to(Merb::Test::Fixtures::Controllers::Base, :hidden) }.
      should raise_error(Merb::ControllerExceptions::ActionNotFound)
  end
  
  it "should dispatch to included methods with show_action called" do
    dispatch_to(Merb::Test::Fixtures::Controllers::Base, :baz).body.should == "baz"
  end

  it "should not dispatch to included methods with show_action not called" do
    calling { dispatch_to(Merb::Test::Fixtures::Controllers::Base, :bat) }.
      should raise_error(Merb::ControllerExceptions::ActionNotFound)
  end
  
  it "should support hooks before dispatch with a proc" do
    controller = dispatch_to(Merb::Test::Fixtures::Controllers::BeforeHook, :index)
    controller.body.should == "Proc"
  end

  it "should support hooks before dispatch with a proc" do
    controller = dispatch_to(Merb::Test::Fixtures::Controllers::BeforeHookInherit, :index)
    controller.body.should == "Proc"
  end

  it "should support hooks before dispatch with a symbol (and inherit)" do
    controller = dispatch_to(Merb::Test::Fixtures::Controllers::BeforeHookSymbol, :index)
    controller.body.should == "Proc Symbol"
  end
  
  it "should support hooks after dispatch with a proc" do
    controller = dispatch_to(Merb::Test::Fixtures::Controllers::AfterHook, :index)
    controller.body.should == "Proc"
  end

  it "should support hooks after dispatch with a symbol (and inherit)" do
    controller = dispatch_to(Merb::Test::Fixtures::Controllers::AfterHookSymbol, :index)
    controller.body.should == "Proc Symbol"
  end
    
end