*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/NPSPSettingsPageObject.py
...             robot/Cumulus/resources/GiftEntryPageObject.py
Suite Setup     Run keywords
...             Open Test Browser
...             API Check And Enable Gift Entry
Suite Teardown  Capture Screenshot and Delete Records and Close Browser

*** Keywords ***

Get Template Builder Field Names
  @{builder_form_fields} =  Return Form Field Titles  template_builder_fields
  ${builder_labels} =  Create List

  FOR  ${label}  IN  @{builder_form_fields}
      ${name} =  Get Text  ${label}
      Append to List  ${builder_labels}  ${name}
  END

  Set Suite Variable  ${builder_labels}


Get Template Form Field Names
  @{gift_form_fields} =  Return Form Field Titles  gift_entry_form
  ${form_labels} =  Create List

  FOR  ${label}  IN  @{gift_form_fields}
      ${name} =  Get Text  ${label}
      Append to List  ${form_labels}  ${name}
  END
  
  Set Suite Variable  ${form_labels}

Get Template Builder Section Names
  @{builder_section_titles} =  Return Form Field Titles  template_builder_sections
  ${builder_s_titles} =  Create List

  FOR  ${label}  IN  @{builder_section_titles}
      ${name} =  Get Text  ${label}
      Append to List  ${builder_s_titles}  ${name}
  END

  Set Suite Variable  ${builder_section_titles}

Get Form Section Names
  @{form_section_titles} =  Return Form Field Titles  template_builder_sections
  ${form_s_titles} =  Create List

  FOR  ${label}  IN  @{form_section_titles}
      ${name} =  Get Text  ${label}
      Append to List  ${form_s_titles}  ${name}
  END

  Set Suite Variable  ${form_section_titles}


*** Test Cases ***

Reorder and Modify GE Template Fields
  [Documentation]                       Tests adding, deleting, and reordering form fields on the template builder,
  ...                                   and compares the order of the template form fields with the order of the 
  ...                                   gift form in a batch created from that template.
  [tags]                                unstable                    feature:GE          W-039563
  ${template} =                         Generate Random String
  Go to Page                            Landing                     GE_Gift_Entry
  Click Link                            Templates
  Click Gift Entry Button               Create Template
  Current Page Should Be                Template                    GE_Gift_Entry
  Enter Value in Field
  ...                                   Template Name=${template}
  ...                                   Description=This is created by automation script 
  Click Gift Entry Button               Next: Form Fields
  #Adds 'Role' form field from the AccountSoftCredits section
  Perform Action On Object Field        select                     AccountSoftCredits  Role
  Perform Action On Object Field        select                     CustomObject1  CustomObject1Imported
  #Moves the CustomObject1Imported field up in the field order
  Click Gift Entry Button               button Up Data Import: CustomObject1Imported
  #Moves the Add or Edit Organization Account section up in the field order
  Click Gift Entry Button               button Up Add or Edit Organization Account
  #Deletes the Payment: Check/Reference Number field from the template
  Perform Action On Object Field        unselect                   Payment       Check/Reference Number
  Verify Template Builder               contains                   AccountSoftCredits: Role
  Verify Template Builder               does not contain           Payment: Check/Reference Number
  Get Template Builder Field Names
  Click Gift Entry Button               Save & Close
  Current Page Should Be                Landing                    GE_Gift_Entry
  #Creates new batch with the new template
  Click Gift Entry Button               New Batch
  Select Template                       ${template}
  Load Page Object                      Form                       Gift Entry
  Click Button                          Next
  Fill Gift Entry Form
  ...                                   Batch Name=${template}
  ...                                   Batch Description=This is a test batch created via automation script
  Click Gift Entry Button               Next
  Click Gift Entry Button               Save
  Current Page Should Be                Form                        Gift Entry   title=Gift Entry Form 
  # Confirms fields added are present, and deleted fields are not present
  Page Should Contain                   AccountSoftCredits: Role        
  Page Should Not Contain               Check/Reference Number
  #Gets form field labels and compares the order to the template builder page
  Get Template Form Field Names
  Lists Should Be Equal                 ${builder_labels}  ${form_labels}
  Lists Should Be Equal                 ${builder_section_titles}  ${form_section_titles}
  ${batch_id} =                         Save Current Record ID For Deletion      DataImportBatch__c