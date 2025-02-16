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



unit TabComponent;

interface

uses
   System.Classes, Vcl.ComCtrls, Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, WinApi.Windows,
   Vcl.Graphics, WinApi.Messages, Interfaces, OmniXML, Element, PageControl_Form,
   Types, Generics.Defaults;

type

   TTabComponent = class(TTabSheet, IXMLable, IWithId, IWithTab, IWithName, IWithSizeEdits, IWithFocus, IExportable, IGenericComparable)
      private
         FParentForm: TPageControlForm;
         FId: integer;
      protected
         FParentObject: TComponent;
         FActive,
         FCodeIncludeExtern: boolean;
         FElementTypeId: string;
         sbxElements: TScrollBox;
         procedure SetActive(AValue: boolean); virtual;
         function GetActive: boolean; virtual;
         procedure AddElement(Sender: TObject); virtual;
         function GetId: integer;
         function CreateElement: TElement; virtual; abstract;
         function GetElementCount: integer;
         function GetScrollPos: integer;
         procedure SetScrollPos(AValue: integer);
         procedure OnChangeLib(Sender: TObject);
         procedure OnClickCh(Sender: TObject); virtual;
         procedure OnChangeName(Sender: TObject); virtual;
         procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
         procedure CreateExtDeclareChBox(AParent: TWinControl; x, y: integer; AAlignment: TLeftRight = taRightJustify);
         procedure CreateNameControls(AParent: TWinControl; x, y: integer);
         procedure CreateLibControls(AParent: TWinControl; x, y: integer);
         function GetElements<T: class>(AComparer: IComparer<T> = nil): IEnumerable<T>;
      public
         edtName: TEdit;
         chkExternal: TCheckBox;
         edtLibrary: TEdit;
         lblName: TLabel;
         lblLibrary: TLabel;
         btnAddElement: TButton;
         property Id: integer read GetId;
         property Active: boolean read FActive write SetActive;
         property ParentObject: TComponent read FParentObject;
         property ParentForm: TPageControlForm read FParentForm;
         constructor Create(AParentForm: TPageControlForm);
         destructor Destroy; override;
         procedure ExportToXML(ANode: IXMLNode); virtual;
         function ExportToXMLFile(const AFile: string): TError;
         procedure ExportToGraphic(AGraphic: TGraphic);
         function GetExportFileName: string;
         function IsDuplicated(ANameEdit: TEdit): boolean;
         procedure ImportFromXML(ANode: IXMLNode; APinControl: TControl = nil); virtual;
         function GetLibrary: string;
         property ScrollPos: integer read GetScrollPos write SetScrollPos;
         function GetName: string;
         function GetTab: TTabSheet;
         procedure RefreshSizeEdits; virtual; abstract;
         function RetrieveFocus(AInfo: TFocusInfo): boolean;
         function CanBeFocused: boolean;
         function GetTreeNodeText(ANodeOffset: integer = 0): string; virtual;
         function IsDuplicatedElement(AElement: TElement): boolean;
         procedure RefreshElements; virtual;
         function HasInvalidElement: boolean;
         function GetFocusColor: TColor;
         function Remove(ANode: TTreeNodeWithFriend = nil): boolean;
         function CanRemove: boolean;
         function IsBoldDesc: boolean;
         procedure RefreshFontColor;
         procedure UpdateCodeEditor;
         function GetCompareValue(ACompareType: integer): integer;
         function GetExternModifier: string; virtual; abstract;
   end;

implementation

uses
   System.SysUtils, Generics.Collections, System.Rtti, Infrastructure, XMLProcessor,
   OmniXMLUtils, BaseEnumerator, Constants;

var
   ByTopElementComparer: IComparer<TElement>;

constructor TTabComponent.Create(AParentForm: TPageControlForm);
begin
   inherited Create(AParentForm.pgcTabs);
   PageControl := AParentForm.pgcTabs;
   ParentFont := False;
   ParentBackground := False;
   Brush.Color := AParentForm.Color;
   Align := alClient;
   Font.Color := NOK_COLOR;
   Font.Style := [fsBold];
   DoubleBuffered := True;
   FParentObject := Self;
   FActive := True;
   FId := GProject.Register(Self);
   FParentForm := AParentForm;
end;

destructor TTabComponent.Destroy;
begin
   GProject.UnRegister(Self);
   inherited Destroy;
end;

procedure TTabComponent.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
   FillRect(Msg.DC, ClientRect, Brush.Handle);
   Msg.Result := 1;
end;

procedure TTabComponent.UpdateCodeEditor;
begin
   if FCodeIncludeExtern or not chkExternal.Checked then
      TInfra.UpdateCodeEditor(Self);
end;

function TTabComponent.RetrieveFocus(AInfo: TFocusInfo): boolean;
begin
   if FActive then
   begin
      FParentForm.Show;
      Show;
      if not AInfo.SelText.IsEmpty then
      begin
         for var elem in GetElements<TElement> do
         begin
            if SameText(Trim(elem.edtName.Text), AInfo.SelText) then
            begin
               if elem.edtName.CanFocus and (AInfo.ActiveControl = nil) then
                  elem.edtName.SetFocus;
               break;
            end;
         end;
      end;
      if (AInfo.ActiveControl <> nil) and AInfo.ActiveControl.CanFocus then
         AInfo.ActiveControl.SetFocus;
   end;
   result := FActive;
end;

function TTabComponent.CanBeFocused: boolean;
begin
   result := FActive;
end;

procedure TTabComponent.OnChangeLib(Sender: TObject);
begin
   GProject.SetChanged;
   if Font.Color <> NOK_COLOR then
      TInfra.UpdateCodeEditor(Self);
end;

function TTabComponent.ExportToXMLFile(const AFile: string): TError;
begin
   result := TXMLProcessor.ExportToXMLFile(ExportToXML, AFile);
end;

function TTabComponent.GetExportFileName: string;
begin
   result := edtName.Text;
end;

procedure TTabComponent.ExportToGraphic(AGraphic: TGraphic);
var
   bitmap: TBitmap;
begin
   if AGraphic is TBitmap then
      bitmap := TBitmap(AGraphic)
   else
      bitmap := TBitmap.Create;
   bitmap.Width := Width;
   bitmap.Height := Height;
   bitmap.Canvas.Lock;
   PaintTo(bitmap.Canvas, 0, 0);
   bitmap.Canvas.Unlock;
   if AGraphic <> bitmap then
   begin
      AGraphic.Assign(bitmap);
      bitmap.Free;
   end;
end;

procedure TTabComponent.CreateExtDeclareChBox(AParent: TWinControl; x, y: integer; AAlignment: TLeftRight = taRightJustify);
begin
   chkExternal := TCheckBox.Create(AParent);
   chkExternal.Parent := AParent;
   chkExternal.Alignment := AAlignment;
   if not FCodeIncludeExtern then
      chkExternal.Hint := i18Manager.GetString('chkExternal.Hint');
   if GInfra.CurrentLang.ExternalLabel.IsEmpty then
      chkExternal.Caption := i18Manager.GetString('chkExternal')
   else
      chkExternal.Caption := GInfra.CurrentLang.ExternalLabel;
   chkExternal.ParentFont := False;
   chkExternal.Font.Style := [];
   chkExternal.Font.Color := clWindowText;
   chkExternal.SetBounds(x, y, TInfra.GetAutoWidth(chkExternal), 17);
   chkExternal.DoubleBuffered := True;
   chkExternal.OnClick := OnClickCh;
   chkExternal.ShowHint := True;
end;

procedure TTabComponent.CreateNameControls(AParent: TWinControl; x, y: integer);
begin
   lblName := TLabel.Create(AParent);
   lblName.Parent := AParent;
   lblName.SetBounds(x, y, 0, 13);
   lblName.Caption := i18Manager.GetString('lblName');
   lblName.ParentFont := False;
   lblName.Font.Style := [];
   lblName.Font.Color := clWindowText;

   edtName := TEdit.Create(AParent);
   edtName.Parent := AParent;
   edtName.SetBounds(lblName.BoundsRect.Right+5, y-6, 104, 21);
   edtName.ParentFont := False;
   edtName.Font.Style := [];
   edtName.ShowHint := True;
   edtName.Hint := i18Manager.GetString('BadIdD');
   edtName.DoubleBuffered := True;
   edtName.OnChange := OnChangeName;
end;

procedure TTabComponent.CreateLibControls(AParent: TWinControl; x, y: integer);
begin
   lblLibrary := TLabel.Create(AParent);
   lblLibrary.Parent := AParent;
   lblLibrary.SetBounds(x, y, 0, 13);
   lblLibrary.Caption := i18Manager.GetString('lblLibrary');
   lblLibrary.ParentFont := False;
   lblLibrary.Font.Style := [];
   lblLibrary.Font.Color := clWindowText;

   edtLibrary := TEdit.Create(AParent);
   edtLibrary.Parent := AParent;
   edtLibrary.SetBounds(lblLibrary.BoundsRect.Right+5, y-6, 135-lblLibrary.Width, 21);
   edtLibrary.ParentFont := False;
   edtLibrary.Font.Style := [];
   edtLibrary.Font.Color := clGreen;
   edtLibrary.ShowHint := True;
   edtLibrary.DoubleBuffered := True;
   edtLibrary.OnChange := OnChangeLib;
   edtLibrary.Hint := i18Manager.GetFormattedString('edtLibraryHint', [GInfra.CurrentLang.LibraryExt]);
end;

procedure TTabComponent.OnClickCh(Sender: TObject);
begin
   GProject.SetChanged;
   if Font.Color <> NOK_COLOR then
      TInfra.UpdateCodeEditor(Self);
end;

procedure TTabComponent.SetActive(AValue: boolean);
begin
   if AValue <> FActive then
   begin
      FActive := AValue;
      TabVisible := FActive;
      GProject.SetChanged;
      FParentForm.UpdateCodeEditor := False;
      for var i := 0 to PageControl.PageCount-1 do
      begin
         var tab := TTabComponent(PageControl.Pages[i]);
         if tab.TabVisible and Assigned(tab.edtName.OnChange) then
            tab.edtName.OnChange(tab.edtName);
      end;
      FParentForm.UpdateCodeEditor := True;
   end;
end;

function TTabComponent.GetLibrary: string;
begin
   result := '';
   if FActive and (Font.Color <> NOK_COLOR) then
      result := Trim(edtLibrary.Text);
end;

function TTabComponent.GetActive: boolean;
begin
   result := FActive;
end;

function TTabComponent.GetElementCount: integer;
begin
   result := 0;
   for var i := 0 to sbxElements.ControlCount-1 do
   begin
      if sbxElements.Controls[i].Visible then
         Inc(result);
   end;
end;

function TTabComponent.IsDuplicated(ANameEdit: TEdit): boolean;
begin
   result := False;
   if ANameEdit <> nil then
   begin
      for var i := 0 to PageControl.PageCount-1 do
      begin
         var tab := TTabComponent(PageControl.Pages[i]);
         if tab.TabVisible and (tab.edtName <> ANameEdit) and TInfra.SameStrings(Trim(tab.edtName.Text), Trim(ANameEdit.Text)) then
         begin
            result := True;
            break;
         end;
      end;
   end;
end;

procedure TTabComponent.RefreshFontColor;
begin
   if HasInvalidElement then
      Font.Color := NOK_COLOR
   else
      Font.Color := edtName.Font.Color;
end;

function TTabComponent.GetElements<T>(AComparer: IComparer<T> = nil): IEnumerable<T>;
begin
   var list := TList<T>.Create;
   for var i := 0 to sbxElements.ControlCount-1 do
   begin
      var control := sbxElements.Controls[i];
      if control.Visible and (control is T) then
         list.Add(control);
   end;
   if AComparer <> nil then
      list.Sort(AComparer);
   result := TEnumeratorFactory<T>.Create(list);
end;

function TTabComponent.GetScrollPos: integer;
begin
   result := sbxElements.VertScrollBar.Position;
end;

procedure TTabComponent.SetScrollPos(AValue: integer);
begin
   sbxElements.VertScrollBar.Position := AValue;
end;

procedure TTabComponent.AddElement(Sender: TObject);
var
   elem: TElement;
begin
   sbxElements.LockDrawing;
   try
      elem := CreateElement;
      sbxElements.Height := sbxElements.Height + elem.Height;
   finally
      sbxElements.UnlockDrawing;
   end;
   if elem.edtName.CanFocus then
   begin
      elem.edtName.SetFocus;
      elem.edtName.OnChange(elem.edtName);
   end;
   PageControl.Refresh;
   UpdateCodeEditor;
end;

function TTabComponent.GetName: string;
begin
   result := '';
   if FActive and (Font.Color <> NOK_COLOR) then
      result := Trim(edtName.Text);
end;

function TTabComponent.GetTab: TTabSheet;
begin
   result := Self;
end;

function TTabComponent.GetId: integer;
begin
   result := FId;
end;

procedure TTabComponent.OnChangeName(Sender: TObject);
begin
   Caption := Trim(edtName.Text);
   PageControl.Refresh;
   if FParentForm.UpdateCodeEditor then
      UpdateCodeEditor;
   GProject.SetChanged;
end;

function TTabComponent.HasInvalidElement: boolean;
begin
   result := False;
   for var elem in GetElements<TElement> do
   begin
      if not elem.IsValid then
      begin
         result := True;
         break;
      end;
   end;
end;

function TTabComponent.IsDuplicatedElement(AElement: TElement): boolean;
begin
   result := False;
   if (AElement <> nil) and (AElement.ParentTab = Self) then
   begin
      for var elem in GetElements<TElement> do
      begin
         if (elem <> AElement) and TInfra.SameStrings(Trim(AElement.edtName.Text), Trim(elem.edtName.Text)) then
         begin
            result := True;
            break;
         end;
      end;
   end;
end;

procedure TTabComponent.RefreshElements;
begin
   FParentForm.UpdateCodeEditor := False;
   for var elem in GetElements<TElement> do
      elem.edtName.OnChange(elem.edtName);
   FParentForm.UpdateCodeEditor := True;
end;

procedure TTabComponent.ExportToXML(ANode: IXMLNode);
begin
   SetNodeAttrInt(ANode, ID_ATTR, FId);
   SetNodeAttrStr(ANode, NAME_ATTR, Trim(edtName.Text));
   SetNodeAttrStr(ANode, 'ext_decl', TRttiEnumerationType.GetName(chkExternal.State));
   SetNodeAttrStr(ANode, 'library', Trim(edtLibrary.Text));
   for var elem in GetElements<TElement>(ByTopElementComparer) do
      elem.ExportToXML(ANode);
end;

procedure TTabComponent.ImportFromXML(ANode: IXMLNode; APinControl: TControl = nil);
begin
   edtName.Text := GetNodeAttrStr(ANode, NAME_ATTR);
   if Assigned(edtName.OnChange) then
      edtName.OnChange(edtName);
   chkExternal.State := TInfra.DecodeCheckBoxState(GetNodeAttrStr(ANode, 'ext_decl'));
   edtLibrary.Text := GetNodeAttrStr(ANode, 'library');
   var nodes := FilterNodes(ANode, FElementTypeId);
   var node := nodes.NextNode;
   while node <> nil do
   begin
      var elem := CreateElement;
      sbxElements.Height := sbxElements.Height + elem.Height;
      elem.ImportFromXML(node);
      node := nodes.NextNode;
   end;
   FId := GProject.Register(Self, GetNodeAttrInt(ANode, ID_ATTR));
end;

function TTabComponent.GetFocusColor: TColor;
begin
   if HasParent then
      result := Font.Color
   else
      result := OK_COLOR;
end;

function TTabComponent.Remove(ANode: TTreeNodeWithFriend = nil): boolean;
begin
   result := CanRemove;
   if result then
   begin
      FParentForm.pgcTabs.ActivePage := Self;
      FParentForm.miRemove.OnClick(FParentForm.miRemove);
   end;
end;

function TTabComponent.CanRemove: boolean;
begin
   result := FActive;
end;

function TTabComponent.IsBoldDesc: boolean;
begin
   result := False;
end;

function TTabComponent.GetTreeNodeText(ANodeOffset: integer = 0): string;
begin
   result := Caption;
end;

function TTabComponent.GetCompareValue(ACompareType: integer): integer;
begin
   result := -1;
   if ACompareType = PAGE_INDEX_COMPARE then
      result := PageIndex;
end;

initialization

   ByTopElementComparer := TElementComparer.Create(TOP_COMPARE);

end.
