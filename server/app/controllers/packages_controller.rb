require 'rexml/document'

class PackagesController < ApplicationController
  skip_before_filter :verify_authenticity_token

  # lists out all packages
  def index
    # whether we want to show all packages or only packages
    # that are currently installed
    show_all = true
    @mainmodel = Package 

    sort = case params[:sort]
           when 'name'              then 'packages.name'
           when 'name_reverse'      then 'packages.name DESC'
           when 'filename'              then 'packages.filename'
           when 'filename_reverse'      then 'packages.filename DESC'
           when 'maintainer'        then 'packages.maintainer'
           when 'maintainer_reverse'        then 'packages.maintainer DESC'
           when 'os'        then 'packages.os'
           when 'os_reverse'        then 'packages.os DESC'
           when 'arch'        then 'packages.arch'
           when 'arch_reverse'        then 'packages.arch DESC'
           
           end
    # If a sort was not defined we'll make one default
    if sort.nil?
      params[:sort] = 'name'
      sort = 'packages.name'
    end

#    def_attr = @mainmodel.default_search_attribute                                                  
    # Set the sort var ; used later in the find query                                               
#    if params['sort'].nil?
#      params['sort'] = @mainmodel.default_search_attribute                                         
#      sort = "#{@mainmodel.to_s.tableize}.#{def_attr}"
#    elsif params['sort'] == def_attr.to_s
#      sort = "#{@mainmodel.to_s.tableize}.#{def_attr}"                                              
#    elsif params['sort'] == "#{def_attr}_reverse"
#      sort = "#{@mainmodel.to_s.tableize}.#{def_attr} DESC"                                         
#    elsif params['sort'] =~ /(.*)_reverse/
#      puts "HERE and it is #{$1}"
#      this_model = $1.camelize.constantize
#      sort = "#{this_model.to_s.tableize}.#{this_model.default_search_attribute} DESC"              
#    else
#      params['sort'] =~ /(.*)/                                                                     
#      this_model = $1.camelize.constantize                                                          
#      sort = "#{this_model.to_s.tableize}.#{this_model.default_search_attribute}"                   
#    end

    conditions_query = []
    conditions_values = []
    params.each_pair do |key, value|
      next if key == 'action'
      next if key == 'controller'
      next if key == 'format'
      next if key == 'page'
      next if key == 'sort' 

      if key == @mainmodel.default_search_attribute
        conditions_query << "name LIKE ?"
        conditions_values << '%' + value + '%'
      end
    end

    if show_all
      join = nil
    else
      join = "inner join client_packages as cp on packages.id = cp.package_id"
    end

    if conditions_query.empty?
      @packages = Package.paginate(:all,
                                 #:include => includes,
                                 :group => "packages.id",
                                 :order => sort,
                                 :joins => join,
                                 :page => params[:page])
    else
      conditions_string = conditions_query.join(' AND ')
      @packages = Package.paginate(:all,
                                 #:include => includes,
                                 :conditions => [ conditions_string, *conditions_values ],
                                 :group => "packages.id",
                                 :order => sort,
                                 :joins => join,
                                 :page => params[:page])
    end

    respond_to do |format|
      format.html 
      format.xml  { render :xml => @packages.to_xml(:dasherize => false) }
    end
  end

  def show
    @package = Package.find(params[:id])
    @installed_on = @package.client_packages.collect{ |cp| cp.client}.flatten
    @installed_on.sort!{ |a,b| a.name <=> b.name}

    # Get additional info regarding the package file
    @uploads = []
    if @package.filename
      @uploads = Upload.find_all_by_upload_file_name(@package.filename, :order => "updated_at DESC")
    end

    respond_to do |format|
      format.html 
      format.xml  { render :xml => @package.to_xml(:include => :client_packages, :dasherize => false) }
    end

  end

  def download
    filename = params[:filename]
    if File.exists?(File.join(Upload::UPLOAD_PATH, filename))
      redirect_to :controller => :tpkg, :action => filename
    else
      render :text => "File #{filename} doesn't exist on repo"
    end
  end

  protected
  def add
    name = params[:id]
    package = Package.new
    package.name = name
    package.save
  end

  def delete_all
    Package.delete_all
  end  

  # assuming that the packages list is sent from POST param with the following
  # format 
  # {p1[name]=>"package name", p1[version]=>"1.2", p2[name]=>"package name", p2[version]="3.1.3"}
  #
  def get_packages_info(params)
    packages = Hash.new
    params.each do | key, value |
      packages.merge!({key=> value}) if (key != "action" && key != "controller")
    end
    return packages
  end
end
