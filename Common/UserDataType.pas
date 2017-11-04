{
   Copyright (C) 2006 The devFlowcharter project.
   The initial author of this file is Michal Domagala.
      
   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
}



unit UserDataType;

interface

uses
   Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls, System.Classes, WinApi.Messages, Vcl.ExtCtrls,
   OmniXML, SizeEdit, TabComponent, Element, DataTypes_Form, CommonInterfaces, CommonTypes;

type

   TUserDataType = class;

   TField = class(TElement)
      constructor Create(AParentTab: TUserDataType);
   protected
      procedure OnChangeSize(Sender: TObject);
      procedure OnChangeName(Sender: TObject); override;
   public
      edtSize: TSizeEdit;
      function ExportToXMLTag(ATag: IXMLElement): IXMLElement; override;
      procedure ImportFromXMLTag(ATag: IXMLElement); override;
      function IsValid: boolean; override;
   end;

   TUserDataType = class(TTabComponent)
   protected
      procedure OnChangeName(Sender: TObject); override;
      procedure OnClickType(Sender: TObject);
      procedure SetActive(AValue: boolean); override;
      function CreateElement: TElement; override;
      procedure AddElement(Sender: TObject); override;
      procedure WMSize(var Msg: TMessage); message WM_SIZE;
   public
      chkAddPtrType: TCheckBox;
      rgTypeBox: TRadioGroup;
      lblName2,
      lblType,
      lblSize: TLabel;
      property FieldCount: integer read GetElementCount default 0;
      constructor Create(AParentForm: TDataTypesForm);
      procedure ExportToXMLTag(ATag: IXMLElement); override;
      procedure ImportFromXMLTag(ATag: IXMLElement; APinControl: TControl = nil);
      procedure Localize(AList: TStringList); override;
      procedure RefreshSizeEdits; override;
      function IsValidEnumValue(const AValue: string): boolean;
      function GetDimensionCount: integer;
      function GetDimensions: string;
      function GetOriginalType: integer;
      procedure GenerateTree(ANode: TTreeNode);
      function Kind: TUserDataTypeKind;
      function GetFields: IEnumerable<TField>;
   end;

implementation

uses
   Vcl.Forms, Vcl.Graphics, System.SysUtils, System.StrUtils, ApplicationCommon, LangDefinition, ParserHelper, XMLProcessor;

constructor TUserDataType.Create(AParentForm: TDataTypesForm);
var
   dt: TUserDataTypeKind;
   s: string;
begin

   inherited Create(AParentForm);

   FElementMode := FIELD_IDENT;

   CreateNameControls(Self, 9, 10);

   lblName2 := TLabel.Create(Self);
   lblName2.Parent := Self;
   lblName2.ParentFont := false;
   lblName2.Font.Style := [fsBold];
   lblName2.Font.Color := clWindowText;
   lblName2.SetBounds(5, 131, 0, 13);
   lblName2.Caption := i18Manager.GetString('lblField');

   lblSize := TLabel.Create(Self);
   lblSize.Parent := Self;
   lblSize.ParentFont := false;
   lblSize.Font.Style := [fsBold];
   lblSize.Font.Color := clWindowText;
   lblSize.SetBounds(195, 131, 0, 13);
   lblSize.Caption := i18Manager.GetString('lblSize');

   lblType := TLabel.Create(Self);
   lblType.Parent := Self;
   lblType.ParentFont := false;
   lblType.Font.Style := [fsBold];
   lblType.Font.Color := clWindowText;
   lblType.SetBounds(87, 131, 0, 13);
   lblType.Caption := i18Manager.GetString('lblType');

   sbxElements := TScrollBox.Create(Self);
   sbxElements.Parent := Self;
   sbxElements.Ctl3D := false;
   sbxElements.BorderStyle := bsNone;
   sbxElements.Constraints.MaxHeight := AParentForm.Height - 233;
   sbxElements.Constraints.MinWidth := 302;
   sbxElements.SetBounds(0, 149, 308, 0);
   sbxElements.VertScrollBar.Tracking := true;
   sbxElements.DoubleBuffered := true;
   sbxElements.Anchors := [akTop, akBottom, akLeft, akRight];

   btnAddElement := TButton.Create(Self);
   btnAddElement.Parent := Self;
   btnAddElement.ParentFont := false;
   btnAddElement.Font.Style := [];
   btnAddElement.Caption := i18Manager.GetString('btnAddField');
   btnAddElement.ShowHint := true;
   btnAddElement.DoubleBuffered := true;
   btnAddElement.SetBounds(1, 102, 306, 25);
   btnAddElement.OnClick := AddElement;

   CreateLibControls(Self, edtName.Left+edtName.Width+7, 10);

   chkAddPtrType := TCheckBox.Create(Self);
   chkAddPtrType.Parent := Self;
   chkAddPtrType.SetBounds(180, 42, 134, 17);
   chkAddPtrType.ParentFont := false;
   chkAddPtrType.Font.Style := [];
   chkAddPtrType.Font.Color := clWindowText;
   chkAddPtrType.DoubleBuffered := true;
   chkAddPtrType.Caption := i18Manager.GetString('chkAddPtrType');
   chkAddPtrType.Enabled := GInfra.CurrentLang.EnabledPointers;
   chkAddPtrType.OnClick := OnClickCh;

   CreateExtDeclareChBox(Self, 180, 60);

   rgTypeBox := TRadioGroup.Create(Self);
   rgTypeBox.Parent := Self;
   rgTypeBox.SetBounds(1, 28, 173, 73);
   rgTypeBox.ParentFont := false;
   rgTypeBox.ParentBackground := false;
   rgTypeBox.Font.Style := [];
   rgTypeBox.Font.Color := clWindowText;
   rgTypeBox.DoubleBuffered := true;
   rgTypeBox.Columns := 2;
   rgTypeBox.Caption := i18Manager.GetString('rgTypeBox');

   for dt := Low(TUserDataTypeKind) to High(TUserDataTypeKind) do
   begin
      s := TInfra.EnumToString<TUserDataTypeKind>(dt);
      rgTypeBox.Items.Add(i18Manager.GetString(s));
   end;

   rgTypeBox.ItemIndex := Ord(dtRecord);
   rgTypeBox.OnClick := OnClickType;

   GProject.AddComponent(Self);
end;

function TUserDataType.Kind: TUserDataTypeKind;
begin
   result := TUserDataTypeKind(rgTypeBox.ItemIndex);
end;

procedure TUserDataType.SetActive(AValue: boolean);
begin
   if AValue <> FActive then
   begin
      inherited SetActive(AValue);
      ParentForm.FormDeactivate(ParentForm);
      ParentForm.RefreshTabs;
   end;
end;

procedure TUserDataType.AddElement(Sender: TObject);
begin
   if (Kind in [dtOther, dtArray]) and (sbxElements.ControlCount = 0) then
      btnAddElement.Enabled := false;
   inherited AddElement(Sender);
end;

procedure TUserDataType.RefreshSizeEdits;
var
   i: integer;
   field: TField;
begin
   ParentForm.UpdateCodeEditor := false;
   for i := 0 to sbxElements.ControlCount-1 do
   begin
      field := TField(sbxElements.Controls[i]);
      if field.edtSize.Text <> '1' then
         field.edtSize.OnChange(field.edtSize);
   end;
   ParentForm.UpdateCodeEditor := true;
end;

procedure TUserDataType.WMSize(var Msg: TMessage);
begin
   inherited;
   if sbxElements <> nil then
   begin
      sbxElements.Constraints.MaxHeight := ParentForm.Height - 233;
      sbxElements.Height := sbxElements.Constraints.MaxHeight;
   end;
end;

procedure TUserDataType.OnClickType(Sender: TObject);
var
   b: boolean;
   field: TField;
   i: integer;
   t: TUserDataTypeKind;
   str: string;
begin
   t := Kind;
   b := t in [dtRecord, dtEnum, dtOther, dtArray];
   sbxElements.Enabled := b;
   lblName2.Enabled := b and (t <> dtArray);
   lblSize.Enabled := t in [dtRecord, dtArray];
   lblType.Enabled := lblSize.Enabled;
   if b then
   begin
      str := IfThen(t = dtRecord, 'Field', 'Value');
      btnAddElement.Caption := i18Manager.GetString('btnAdd' + str);
      lblName2.Caption := i18Manager.GetString('lbl' + str);
   end;
   for i := 0 to sbxElements.ControlCount-1 do
   begin
      field := TField(sbxElements.Controls[i]);
      with field do
      begin
         edtName.Enabled := b;
         cbType.Enabled := t = dtRecord;
         btnRemove.Enabled := b;
         edtSize.Enabled := cbType.Enabled;
         if i = 0 then
         begin
            if t = dtOther then
               b := false
            else if t = dtArray then
            begin
               b := false;
               edtName.Enabled := false;
               edtSize.Enabled := true;
               cbType.Enabled := true;
            end;
         end;
      end;
   end;
   btnAddElement.Enabled := b;
   if GInfra.CurrentLang.EnabledPointers then
   begin
      if t = dtEnum then
         chkAddPtrType.Checked := false;
      chkAddPtrType.Enabled := t <> dtEnum;
   end;
   RefreshElements;
   if GProject <> nil then
      GProject.RefreshStatements;
   PageControl.Refresh;
   UpdateCodeEditor;
end;


constructor TField.Create(AParentTab: TUserDataType);
begin

   inherited Create(AParentTab.sbxElements);
   
   FElem_Id := FIELD_IDENT;
   Constraints.MaxWidth := 302;
   SetBounds(0, Parent.Height, 302, 22);
   Align := alTop;

   TInfra.PopulateDataTypeCombo(cbType, ParentTab.PageIndex);

   btnRemove.SetBounds(239, 0, 52, 20);

   edtSize := TSizeEdit.Create(Self);
   edtSize.SetBounds(176, 2, 54, 17);
   edtSize.BorderStyle := bsNone;
   edtSize.OnChange := OnChangeSize;
end;

function TUserDataType.CreateElement: TElement;
var
   field: TField;
   t: TUserDataTypeKind;
begin
   t := Kind;
   field := TField.Create(Self);
   field.cbType.Enabled := t in [dtRecord, dtArray];
   field.edtSize.Enabled := field.cbType.Enabled;
   field.edtName.Enabled := t <> dtArray;
   result := field;
end;

procedure TUserDataType.OnChangeName(Sender: TObject);
var
   info, typeName: string;
   dataType: PNativeDataType;
begin
   edtName.Font.Color := NOK_COLOR;
   typeName := Trim(edtName.Text);
   dataType := GInfra.GetNativeDataType(typeName);
   if typeName.IsEmpty then
      info := 'BadIdD'
   else if IsDuplicated(edtName) then
      info := 'DupType'
   else if dataType <> nil then
      info := 'DefNtvType'
   else
   begin
      edtName.Font.Color := OK_COLOR;
      info := 'OkIdD';
   end;
   edtName.Hint := i18Manager.GetFormattedString(info, [typeName]);
   inherited OnChangeName(Sender);
end;

procedure TUserDataType.ExportToXMLTag(ATag: IXMLElement);
var
   tag: IXMLElement;
begin
   tag := ATag.OwnerDocument.CreateElement(DATATYPE_TAG);
   ATag.AppendChild(tag);
   inherited ExportToXMLTag(tag);
   if chkAddPtrType.Enabled and chkAddPtrType.Checked then
      tag.SetAttribute(POINTER_ATTR, 'true');
   tag.SetAttribute(KIND_ATTR, TInfra.EnumToString<TUserDataTypeKind>(Kind));
end;

procedure TUserDataType.Localize(AList: TStringList);
begin
   lblName2.Caption := AList.Values['lblName'];
   btnAddElement.Caption := AList.Values['btnAddField'];
   btnAddElement.Hint := AList.Values['btnAddFieldHint'];
   chkAddPtrType.Caption := AList.Values['chkAddPtrType'];
   rgTypeBox.Caption := AList.Values['rgTypeBox'];
   edtLibrary.Hint := Format(AList.Values['edtLibHintType'], [GInfra.CurrentLang.LibraryExt]);
   inherited Localize(AList);
end;

procedure TUserDataType.ImportFromXMLTag(ATag: IXMLElement; APinControl: TControl = nil);
begin
   inherited ImportFromXMLTag(ATag, APinControl);
   if chkAddPtrType.Enabled then
      chkAddPtrType.Checked := TXMLProcessor.GetBoolFromAttr(ATag, POINTER_ATTR);
   rgTypeBox.ItemIndex := Ord(TInfra.StringToEnum<TUserDataTypeKind>(ATag.GetAttribute(KIND_ATTR)));
end;

function TUserDataType.GetDimensionCount: integer;
var
   field: TField;
begin
   result := 0;
   if (Kind = dtArray) and (sbxElements.ControlCount > 0) then
   begin
      field := TField(sbxElements.Controls[0]);
      result := field.edtSize.DimensionCount;
   end;
end;

function TUserDataType.GetDimensions: string;
var
   field: TField;
begin
   result := '';
   if (Kind = dtArray) and (sbxElements.ControlCount > 0) then
   begin
      field := TField(sbxElements.Controls[0]);
      result := Trim(field.edtSize.Text);
   end;
end;

function TUserDataType.GetOriginalType: integer;
var
   field: TField;
begin
   result := TParserHelper.GetType(Trim(edtName.Text));
   if (Kind = dtArray) and (sbxElements.ControlCount > 0) then
   begin
      field := TField(sbxElements.Controls[0]);
      result := TParserHelper.GetType(field.cbType.Text);
   end;
end;

function TUserDataType.IsValidEnumValue(const AValue: string): boolean;
var
   field: TField;
   i: integer;
begin
   result := false;
   if Kind = dtEnum then
   begin
      for i := 0 to sbxElements.ControlCount-1 do
      begin
         field := TField(sbxElements.Controls[i]);
         if Trim(field.edtName.Text) = AValue then
         begin
            result := true;
            break;
         end;
      end;
   end;
end;

function TUserDataType.GetFields: IEnumerable<TField>;
begin
   result := GetElements<TField>;
end;

procedure TField.OnChangeName(Sender: TObject);
var
   lColor: TColor;
   lHint: string;
   dataType: TUserDataType;
begin
   dataType := TUserDataType(ParentTab);
   if dataType.Kind in [dtOther, dtArray] then
   begin
      if Trim(edtName.Text) = '' then
      begin
         lColor := NOK_COLOR;
         lHint := 'BadIdD';
      end
      else
      begin
         lColor := OK_COLOR;
         lHint := 'OkIdD';
      end;
      edtName.Font.Color := lColor;
      edtName.Hint := i18Manager.GetString(lHint);
      UpdateMe;
   end
   else
      inherited OnChangeName(Sender);
end;

function TField.ExportToXMLTag(ATag: IXMLElement): IXMLElement;
begin
   inherited ExportToXMLTag(ATag).SetAttribute(SIZE_ATTR, edtSize.Text);
end;

procedure TField.ImportFromXMLTag(ATag: IXMLElement);
var
   size: string;
begin
   inherited ImportFromXMLTag(ATag);
   if TXMLProcessor.GetBoolFromAttr(ATag, 'table') then  // for backward compatibility
      edtSize.Text := '100'
   else
   begin
      size := ATag.GetAttribute(SIZE_ATTR);
      if size.IsEmpty then
         size := '1';
      edtSize.Text := size;
   end;
end;

procedure TField.OnChangeSize(Sender: TObject);
begin
   edtSize.OnChangeSize(edtSize);
   UpdateMe;
   if ParentForm.UpdateCodeEditor then
      TTabComponent(ParentTab).UpdateCodeEditor;
end;

function TField.IsValid: boolean;
begin
   result := inherited IsValid;
   if result and edtSize.Enabled then
      result := edtSize.Font.Color = BLACK_COLOR;
end;

procedure TUserDataType.GenerateTree(ANode: TTreeNode);
var
   desc: string;
   lang: TLangDefinition;
begin
   desc := '';
   lang := nil;
   if Assigned(GInfra.CurrentLang.GetUserTypeDesc) then
      lang := GInfra.CurrentLang
   else if Assigned(GInfra.DummyLang.GetUserTypeDesc) then
      lang := GInfra.DummyLang;
   if lang <> nil then
      desc := lang.GetUserTypeDesc(Self).Trim;
   ANode.Owner.AddChildObject(ANode, desc, Self);
   if TInfra.IsNOkColor(Font.Color) then
   begin
      ANode.MakeVisible;
      ANode.Expand(false);
   end;
end;

end.
